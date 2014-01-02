//
//  PSTConversationCache.m
//  DotMail
//
//  Created by Robert Widmann on 10/10/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//
#import "PSTConversationCache.h"
#import "PSTCachedMessage.h"
#import "FMDatabase.h"
#import "NSString+PSTURL.h"
#import "PSTDatabase.h"
#import "PSTLevelDBMapTable.h"
#import "PSTSerializableMessage.h"

@interface PSTConversationCache ()

@property (nonatomic, strong) NSMutableSet *draftMessageIDs;
@property (nonatomic, strong) NSMutableDictionary *duplicates;
@property (nonatomic, strong) NSMutableSet *pendingFoldersIDs; //DEBUG
@property (nonatomic, copy) NSString *preview;
@property (nonatomic, strong) RACSubject *previewSignal; //DEBUG
@property (nonatomic, weak) PSTDatabase *database;
@property (nonatomic, assign) BOOL isObserver;

@end

@implementation PSTConversationCache

- (id)init {
	if (self = [super init]) {
		self.messages = [[NSMutableArray alloc]init];
		self.previewSignal = [RACSubject subject];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	if (self = [super init]) {
		self.previewSignal = [RACSubject subject];
		self.subject = [aDecoder decodeObjectForKey:@"subject"];
		self.messages = [aDecoder decodeObjectForKey:@"messages"];
		self.actionStep = [aDecoder decodeIntForKey:@"actionStep"];
	}
	return self;
}

- (void)dealloc {
	[self.storage removePreviewObserverForUID:PSTIdentifierForConversationCachePreview(self)];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:self.subject forKey:@"subject"];
	[aCoder encodeObject:self.messages forKey:@"messages"];
	[aCoder encodeInt:self.actionStep forKey:@"actionStep"];
}

- (RACSignal *)previewSignal {
	return _previewSignal;
}

- (void)removeObserverForUID {
	self.isObserver = NO;
	
	[self.storage removePreviewObserverForUID:PSTIdentifierForConversationCachePreview(self)];
}

- (void)addMessageCache:(PSTCachedMessage *)cachedMessage {
	[self.messages addObject:cachedMessage];
}

- (void)addMessage:(PSTSerializableMessage *)cachedMessage rowID:(NSUInteger)rowID folderID:(NSUInteger)folderID {
	if ([self.messages count] == 0) {
		self.subject = nil;
		self.subject = cachedMessage.subject;
	}
	PSTCachedMessage *newMessageCache = [[PSTCachedMessage alloc]initWithMessage:cachedMessage rowID:rowID folderID:folderID];
	
	if (cachedMessage.flags != 0) {
		[self setFlags:cachedMessage.flags];
	}
	[self.messages addObject:newMessageCache];
}

- (void)loadFromDatabase:(PSTDatabase *)database folderID:(NSUInteger)folderID otherFolderID:(NSUInteger)otherFolderID inboxFolderID:(NSUInteger)inboxFolderID draftsFolderID:(NSUInteger)draftsFolderID sentFolderID:(NSUInteger)sentFolderID {
	self.database = database;
	for (PSTCachedMessage *messageCache in self.messages) {
		if (messageCache.folderID == draftsFolderID) {
			if (self.draftMessageIDs == nil) {
				self.draftMessageIDs = [NSMutableSet set];
			}
			[self.draftMessageIDs addObject:messageCache.messageID];
		}
	}
	[self _resolveLabelsWithDatabase:database];
	[self _filterForFolderID:folderID otherFolderID:otherFolderID inboxFolderID:inboxFolderID draftsFolderID:draftsFolderID];
	[self.messages sortUsingSelector:@selector(compare:)];
	for (int i = 0; i < self.messages.count; i++) {
		NSArray *arrayToLoop;
		NSString *key = [(PSTCachedMessage*)[self.messages objectAtIndex:i]uniqueMessageIdentifer];
		if (key != nil) {
			arrayToLoop = [self.duplicates objectForKey:key];
		}
		else {
			arrayToLoop = [NSArray arrayWithObject:[self.messages objectAtIndex:i]];
		}
//		BOOL haz1, haz2, haz3, haz4, haz5;
	}
	NSMutableArray *sendersArray = [NSMutableArray array]; //64
	NSMutableSet *set = [[NSMutableSet alloc]init]; //40
	NSMutableArray *recipientsArray = [[NSMutableArray alloc]init]; //56
	if (self.messages.count != 0) {
		for (int i = 0; i < self.messages.count; i++) {
			PSTCachedMessage *messageCache = [self.messages objectAtIndex:i];
			messageCache.folder = [database folderPathForIdentifier:messageCache.folderID];
//			NSUInteger folderIdentifier = [messageCache folderID];
//			if (folderIdentifier == inboxFolderID || folderIdentifier == folderID) {
				[self _addAddresses:messageCache.recipients toArray:recipientsArray toSet:set];
				[self _addAddresses:@[messageCache.from] toArray:sendersArray toSet:nil];
//			}
		}
	}
	self.count = self.messages.count;
	if (self.count > 2) {
		NSLog(@"");
	}
	if (self.messages.count != 0) {
		PSTCachedMessage *lastMessage = [self.messages lastObject];
		
		self.previewUID = lastMessage.uid;
		self.previewPath = [database folderPathForIdentifier:lastMessage.folderID];
		self.previewRowID = lastMessage.rowID;
		self.previewMessageID = lastMessage.messageID;
		self.flags = lastMessage.flags;
		self.date = lastMessage.internalDate;
		self.senders = sendersArray;
		self.recipients = recipientsArray;
	}
	self.storage = database;
}

- (void)loadPreviewSignals {
	if ([self.database hasPreviewForConversationCache:self]) {
		[_previewSignal sendNext:[self.database previewForConversationCache:self]];
	}
	self.isObserver = YES;
	@weakify(self);
	[self.database addPreviewObserverForUID:PSTIdentifierForConversationCachePreview(self) withBlock:^(NSData *data) {
		@strongify(self);
		[_previewSignal sendNext:[self.database previewForConversationCache:self]];
	}];
}

- (void)_filterForFolderID:(NSUInteger)folderID otherFolderID:(NSUInteger)otherFolderID inboxFolderID:(NSUInteger)inboxFolderID draftsFolderID:(NSUInteger)draftsFolderID {
//	NSMutableDictionary *dupeCaches = [NSMutableDictionary dictionary];
//	for (PSTMessageCache *cache in self.messages) {
//		if (cache.messageID == nil) {
//			continue;
//		}
//		if (cache.folderID != draftsFolderID) {
//			if (cache.folderID != inboxFolderID) {
//				continue;
//			}
//			[dupeCaches setObject:cache forKey:[cache uniqueMessageIdentifer]];
//		}
//	}
//	NSSet *set = [NSSet setWithArray:[dupeCaches allKeys]];
//	self.duplicates = [NSMutableDictionary dictionary];
//	for (PSTMessageCache *cache in self.messages) {
//		if ([set containsObject:[cache uniqueMessageIdentifer]]) {
//			NSMutableArray *dupeArray = [self.duplicates objectForKey:[cache uniqueMessageIdentifer]];
//			if (dupeArray == nil) {
//				[self.duplicates setObject:[NSMutableArray array] forKey:[cache uniqueMessageIdentifer]];
//			}
//			[dupeArray addObject:cache];
//		}
//	}
//	[self.messages removeAllObjects];
//	[self.messages addObjectsFromArray:[set allObjects]];
//	return;
}

- (void)resolveDateUsingFolder:(NSUInteger)folderID {
	NSDate *resultDate = nil;
	for (PSTCachedMessage *message in self.messages) {
		if (folderID == message.folderID) {
			if (resultDate == nil) {
				resultDate = message.internalDate;
			} else if ([message.internalDate compare:resultDate] == NSOrderedDescending) {
				resultDate = message.internalDate;
			}
		}
	}
	if (resultDate == nil) {
		PSTLog(@"Not valid date for %@", self.messages);
		self.date = [[NSDate alloc]init];
	} else {
		self.date = resultDate;
	}
}

- (void)resolveCachedSendersAndRecipients {
	NSMutableArray *fromArray = [[NSMutableArray alloc]init];
	NSMutableArray *recipientsArray = [[NSMutableArray alloc]init];
	NSMutableSet *recipientSet = [[NSMutableSet alloc]init];
	
	if (self.messages.count > 0) {
		int iter = 0;
		NSInteger reverser = self.messages.count - 1;
		do {
			MCOAddress *from = [[self.messages objectAtIndex:reverser]from];
			if (from != nil) {
				[self _addAddresses:@[from] toArray:fromArray toSet:nil];
			}
			iter--;
			
		} while (reverser + 1 > 0);
	}
	if (self.messages.count > 0) {
		int iter = 0;
		NSInteger reverser = self.messages.count - 1;
		do {
			[self _addAddresses:[[self.messages objectAtIndex:reverser]recipients] toArray:recipientsArray toSet:recipientSet];
			iter++;
		} while (self.messages.count > iter);
	}
	self.senders = fromArray;
	self.recipients = recipientsArray;
}

- (void)_addAddresses:(NSArray*)addresses toArray:(NSMutableArray*)destArray toSet:(NSMutableSet*)destSet {
	for (MCOAddress *address in addresses) {
		if (![destSet containsObject:address.mailbox]) {
			if (address.mailbox != nil) {
				[destSet addObject:address.mailbox];
				[destArray addObjectsFromArray:addresses];
			}
		}
	}
}


- (void)_resolveLabelsWithDatabase:(PSTDatabase *)database {
	NSMutableArray *array = [NSMutableArray array];
	for (PSTCachedMessage *messageCache in self.messages) {
		if ([database folderPathForIdentifier:messageCache.folderID] != nil) {
			[array addObject:[database folderPathForIdentifier:messageCache.folderID]];
			for (NSNumber *identifier in self.pendingFoldersIDs) {
				if ([database folderPathForIdentifier:[identifier longLongValue]] != nil) {
					[array addObject:[database folderPathForIdentifier:[identifier longLongValue]]];
				}
			}
			for (NSNumber *identifier in self.labels) {
				if ([database folderPathForIdentifier:[identifier longLongValue]] != nil) {
					[array addObject:[database folderPathForIdentifier:[identifier longLongValue]]];
				}
			}
		}
	}
	self.labels = array;
	[self _normalizeLabels];
}


- (void)_normalizeLabels {
	NSMutableSet *set = [[NSMutableSet alloc]initWithArray:self.labels];
	NSMutableArray *normalized = [[set allObjects]mutableCopy];
	[normalized sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	self.labels = normalized;
}


- (NSArray*)duplicateMessagesForUniqueIdentifier:(NSString*)identifier {
	return [self.duplicates objectForKey:identifier];
}

- (BOOL)isMessageDraft:(MCOIMAPMessage*)message {
	return [self.draftMessageIDs containsObject:message];
}

- (BOOL)hasPendingSendMessages:(NSArray*)sendMessages {
	BOOL retVal = NO;
	for (id object in self.draftMessageIDs) {
		retVal = YES;
		if ([sendMessages containsObject:object]) {
			return retVal;
		}
		retVal = NO;
	}
	return retVal;
}

- (void)clearMessages {
	self.messages = nil;
}

- (void)removeMessageAtIndex:(NSUInteger)index {
	[self.messages removeObjectAtIndex:index];
}

- (void)addLabels:(id)label {
	NSMutableArray *tmpArray = [self.labels mutableCopy];
	[tmpArray addObject:label];
	self.labels = tmpArray;
	[self _normalizeLabels];
}

- (void)removeLabel:(id)label {
	NSMutableArray *tmpArray = [self.labels mutableCopy];
	[tmpArray removeObject:label];
	self.labels = tmpArray;
	[self _normalizeLabels];
}

- (NSString*)description {
	return [NSString stringWithFormat:@"<%@:%p %@ %@ - %@ - %i>", [self class], self, [self messages], [self subject], [self date], self.actionStep];
}

@end
