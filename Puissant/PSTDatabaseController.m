//
//  PSTIMAPAsyncStorage.m
//  DotMail
//
//  Created by Robert Widmann on 10/10/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//
#import <MailCore/mailcore.h>
#import "PSTConversationCache.h"
#import "PSTDatabase.h"
#import "PSTDatabaseController+Operations.h"
#import "PSTConversation.h"
#import "PSTLocalAttachment.h"
#import "PSTMailAccount.h"
#import "PSTLocalMessage.h"
#import "PSTSerializablePart.h"
#import "PSTRemoveMessageCacheOperation.h"
#import "PSTActivity.h"
#import "PSTActivityManager.h"

static RACScheduler *syncScheduler() {
	static RACScheduler *syncScheduler = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		syncScheduler = [RACScheduler scheduler];
	});
	return syncScheduler;
}

@interface PSTDatabaseController ()
@property (nonatomic, strong) PSTLevelDBCache *cacheFile;
@property (nonatomic, strong) PSTIndexedMapTable *conversationsCache;
@property (nonatomic, strong) PSTIndexedMapTable *messagesCache;
@property (nonatomic, strong) PSTLevelDBMapTable *flagsCache;
@property (nonatomic, strong) PSTLevelDBMapTable *labelsCache;
@property (nonatomic, strong) PSTLevelDBMapTable *previewCache;
@property (nonatomic, strong) PSTLevelDBMapTable *plainTextCache;

@property (nonatomic, strong, readonly) NSOperationQueue *queue;

@property (nonatomic, assign) int modifiedConversationsLock;
@property (nonatomic, strong) NSOperationQueue *databaseQueue;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) PSTActivity *rebuildActivity;
@end

@implementation PSTDatabaseController

- (id)init {
	return [self initWithPath:nil];
}

- (id)initWithPath:(NSString *)path {
	self = [super init];
	
	_path = path;
	_databaseQueue = [[NSOperationQueue alloc] init];
	[_databaseQueue setMaxConcurrentOperationCount:1];
	
	_queue = [[NSOperationQueue alloc] init];
	[_queue setMaxConcurrentOperationCount:1];

	return self;
}

- (void)queueOperation:(PSTStorageOperation *)request {
	[_queue addOperation:request];
}

- (void)queueDatabaseOperation:(PSTStorageOperation *)request {
	[request setDatabase:self.databaseConnection];
	[self.databaseQueue addOperation:request];
}

- (RACSignal *)open {
	self.rebuildActivity = [PSTActivity activityWithDescription:@"Opening Database..." forEmail:self.email];
	self.rebuildActivity.maximumProgress = 100.f;
	self.rebuildActivity.progressValue = 0.f;
	@weakify(self);
	return [[[self openDatabase] deliverOn:RACScheduler.mainThreadScheduler] doCompleted: ^{
		@strongify(self);
		self.rebuildActivity.progressValue = 100.f;
		[PSTActivityManager.sharedManager removeActivity:self.rebuildActivity];
		[NSNotificationCenter.defaultCenter postNotificationName:PSTStorageReadyNotification object:self];
	}];
}

- (RACSignal *)openDatabase {
	@weakify(self);
	return [RACSignal createSignal: ^RACDisposable * (id < RACSubscriber > subscriber) {
		@strongify(self);
		return [syncScheduler() schedule: ^{
			@strongify(self);
			for (int i = 0; i < 4; i++) {
				if (i >= 4) {
					PSTLog(@"PSTDatabaseController Failure: Error initializing email database for address: %@", self.email);
					[subscriber sendError:[NSError errorWithDomain:PSTErrorDomain code:-1 userInfo:@{
						NSLocalizedFailureReasonErrorKey : [NSString stringWithFormat:@"PSTDatabaseController failed to open database for %@", self.email]
					}]];
					return;
				}
				[NSFileManager.defaultManager createDirectoryAtPath:self.path withIntermediateDirectories:YES attributes:nil error:nil];
				[NSFileManager.defaultManager createDirectoryAtPath:self.localDraftsPath withIntermediateDirectories:YES attributes:nil error:nil];
				
				self.rebuildActivity.progressValue += 12.5f;

				self.cacheFile = [[PSTLevelDBCache alloc] initWithPath:[self.path stringByAppendingPathComponent:@"data.ldb"]];
				if ([self.cacheFile open] == NO) {
					PSTLog(@"Failure: Cannot open subcache for email %@", self.email);
					[self.countDatabaseConnection close];
					self.countDatabaseConnection = nil;
					[self.databaseConnection close];
					self.databaseConnection = nil;
					self.labelsCache = nil;
					self.flagsCache = nil;
					self.plainTextCache = nil;
					self.previewCache = nil;
					self.messagesCache = nil;
					self.conversationsCache = nil;
					[self.cacheFile close];
					self.cacheFile = nil;
					continue;
				}
				self.conversationsCache = [[PSTIndexedMapTable alloc] initWithPrefix:@"conv."];
				[self.conversationsCache setHashFile:self.cacheFile];
				self.rebuildActivity.progressValue += 12.5f;

				self.messagesCache = [[PSTIndexedMapTable alloc] initWithPrefix:@"msg."];
				[self.messagesCache setHashFile:self.cacheFile];
				self.rebuildActivity.progressValue += 12.5f;

				self.flagsCache = [[PSTLevelDBMapTable alloc] initWithCache:self.cacheFile dataPrefix:@"fl."];
				self.rebuildActivity.progressValue += 12.5f;

				self.labelsCache = [[PSTLevelDBMapTable alloc] initWithCache:self.cacheFile dataPrefix:@"lbl."];
				self.rebuildActivity.progressValue += 12.5f;

				self.previewCache = [[PSTLevelDBMapTable alloc] initWithCache:self.cacheFile dataPrefix:@"prvw."];
				self.rebuildActivity.progressValue += 12.5f;

				self.plainTextCache = [[PSTLevelDBMapTable alloc] initWithCache:self.cacheFile dataPrefix:@"txtpart."];
				self.rebuildActivity.progressValue += 12.5f;

				self.databaseConnection = [PSTDatabase databaseForEmail:self.email withPath:self.path type:PSTDatabaseTypeSerial];
				[self.databaseConnection initializeWithCachesForConversations:self.conversationsCache messages:self.messagesCache previews:self.previewCache text:self.plainTextCache flags:self.flagsCache labels:self.labelsCache];
				self.rebuildActivity.progressValue += 12.5f;
				if ([self.databaseConnection open]) {
					self.countDatabaseConnection = [PSTDatabase databaseForEmail:self.email withPath:self.path type:PSTDatabaseTypeConcurrent];
					[self.countDatabaseConnection initializeWithCachesForConversations:self.conversationsCache messages:self.messagesCache previews:self.previewCache text:self.plainTextCache flags:self.flagsCache labels:self.labelsCache];
					self.rebuildActivity.progressValue += 12.5f;
					if ([self.countDatabaseConnection open]) {
						[self performSelectorOnMainThread:@selector(defrostFolderIdentifiers) withObject:nil waitUntilDone:YES];
						[subscriber sendCompleted];
						return;
					}
				}
				[self.countDatabaseConnection close];
				self.countDatabaseConnection = nil;
				[self.databaseConnection close];
				self.databaseConnection = nil;
				self.labelsCache = nil;
				self.flagsCache = nil;
				self.plainTextCache = nil;
				self.previewCache = nil;
				self.messagesCache = nil;
				self.conversationsCache = nil;
				[self.cacheFile close];
				self.cacheFile = nil;
			}
		}];
	}];
}

- (void)defrostFolderIdentifiers {
	[self.databaseConnection warmFolderIdentifiersCache];
	[self.countDatabaseConnection defrostFolderIdentifiersWithDictionary:[self.databaseConnection foldersIdentifiersMap]];
}

- (void)removeMessageCacheWithMessageID:(NSNumber *)msgID folderPath:(NSString *)path permanently:(BOOL)permanently {
	[self removeMessageCacheWithMessageID:msgID toFolderPaths:[NSArray arrayWithObject:path] permanently:permanently];
}

- (void)removeMessageCacheWithMessageID:(NSNumber *)msgID toFolderPaths:(NSArray *)folderPaths permanently:(BOOL)permanently {
	PSTRemoveMessageCacheOperation *removeCacheop = [[PSTRemoveMessageCacheOperation alloc] init];
	[removeCacheop setPermanently:permanently];
	[removeCacheop setMessageID:msgID];
	[removeCacheop setPaths:folderPaths];
	[removeCacheop setStorage:self];
	[removeCacheop startRequest];
}

- (void)beginConversationUpdates {
	self.modifiedConversationsLock += 1;
}

- (void)endConversationUpdates {
	self.modifiedConversationsLock -= 1;
	PSTStorageOperation *op = [[PSTStorageOperation alloc] init];
	[op setStorage:self];
	[op startRequest];
}

- (void)close {
	[self.countDatabaseConnection close];
	self.countDatabaseConnection = nil;
	[self.databaseConnection close];
	self.databaseConnection = nil;
	[self.cacheFile close];
	self.cacheFile = nil;
	self.labelsCache = nil;
	self.flagsCache = nil;
	self.plainTextCache = nil;
	self.previewCache = nil;
	self.messagesCache = nil;
	self.conversationsCache = nil;
}

- (BOOL)containsFolderPath:(NSString *)path {
	return ([self.countDatabaseConnection identifierForFolderPath:path] != NSUIntegerMax);
}

- (BOOL)hasDataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path {
	BOOL result = YES;
	if (![message isKindOfClass:[PSTLocalMessage class]]) {
		result = [self.databaseConnection hasDataForMessage:message atPath:path];
	}
	return result;
}

- (NSData *)dataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path {
	return [self.databaseConnection dataForMessage:message atPath:path];
}

- (BOOL)hasPreviewForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path {
	return [self.databaseConnection hasPreviewForMessage:message atPath:path];
}

- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	return [self.databaseConnection previewForMessage:message atPath:path];
}

- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment onMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	NSData *retVal = nil;
	if (![attachment isKindOfClass:[PSTLocalAttachment class]]) {
		return [self.databaseConnection dataForAttachmentMessage:message atPath:path partID:[(MCOIMAPMessagePart *)attachment partID] filename:attachment.filename mimeType:attachment.mimeType];
	}
	return retVal;
}

- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path {
	NSData *retVal = nil;
	if (![attachment isKindOfClass:[PSTLocalAttachment class]]) {
//		return [self.databaseConnection dataForAttachmentMessage:attachment.message atPath:path partID:[(MCOIMAPMessagePart *)attachment partID] filename:attachment.filename mimeType:attachment.mimeType];
	}
	return retVal;
}

- (BOOL)hasDataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path {
	BOOL retVal = YES;
	if (![attachment isKindOfClass:[PSTLocalAttachment class]]) {
//		return [self.databaseConnection hasDataForAttachmentMessage:attachment.message atPath:path partID:[(MCOIMAPMessagePart *)attachment partID] filename:attachment.filename mimeType:attachment.mimeType];
	}
	return retVal;
}

PSTConversationCache *PSTConversationCacheForConversation(PSTConversation *conversation, PSTDatabaseController *context) {
	return PSTConversationCacheForConversationID(conversation.conversationID, conversation.folder.path, conversation.otherFolder.path, conversation.account.folders[PSTDraftsFolderPathKey], conversation.account.folders[PSTSentMailFolderPathKey], context.databaseConnection);
}

- (NSUInteger)cachedCountForFolder:(MCOIMAPFolder *)folder {
	return [self.countDatabaseConnection cachedCountForPath:folder.path];
}

- (NSUInteger)cachedUnseenCountForFolder:(MCOIMAPFolder *)folder {
	return [self.countDatabaseConnection cachedUnseenCountForPath:folder.path];
}

- (NSUInteger)cachedCountForStarredNotInTrashFolder:(MCOIMAPFolder *)folder {
	return [self.countDatabaseConnection cachedCountForStarredNotInTrashFolderPath:folder.path];
}

- (NSUInteger)cachedCountForNextStepsNotInTrashFolderPath:(MCOIMAPFolder *)folder {
	return [self.countDatabaseConnection cachedCountForNextStepsNotInTrashFolderPath:folder.path];
}

- (NSUInteger)operationCount {
	return (self.queue.operationCount + self.databaseQueue.operationCount);
}

- (void)updateFolderIdentifiersCache {
	return [self.countDatabaseConnection defrostFolderIdentifiersWithDictionary:[self.databaseConnection foldersIdentifiersMap]];
}

- (NSArray *)messagesLikeMessage:(MCOIMAPMessage *)message inCache:(PSTConversationCache *)cache withFolders:(NSDictionary *)folders {
	return @[];
}

- (void)waitUntilAllOperationsHaveFinished {
	[self.databaseQueue waitUntilAllOperationsAreFinished];
	[self.queue waitUntilAllOperationsAreFinished];
}

- (void)cancelAllOperations {
	[self.databaseQueue cancelAllOperations];
	[self.queue cancelAllOperations];
}

@end