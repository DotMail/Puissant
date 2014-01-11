//
//  PSTAccountSynchronizer.m
//  DotMail
//
//  Created by Robert Widmann on 10/11/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTIMAPAccountSynchronizer.h"
#import "PSTIMAPFolderSynchronizer.h"
#import "PSTMailAccount.h"
#import "PSTConversation.h"
#import "PSTDatabaseController+Operations.h"
#import "PSTConversationCache.h"
#import "PSTActivity.h"
#import "PSTActivityManager.h"
#import "PSTCachedMessage.h"
#import "MCOIMAPSession+PSTExtensions.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

static NSArray *PSTPathsForMessages(NSArray *messages);

@interface PSTIMAPAccountSynchronizer () <PSTStorageOperationDelegate>

@property (nonatomic, strong) MCOIMAPSession *session;

@property (nonatomic, strong) NSMutableDictionary *folderSynchronizers;
@property (nonatomic, strong) NSMutableSet *foldersInSync;
@property (nonatomic, strong) NSMutableArray *updateFolderOperations;
@property (nonatomic, strong) NSMutableDictionary *attachmentSaveFilenames;
@property (nonatomic, strong) NSMutableArray *attachmentQueue;
@property (nonatomic, strong) NSMutableArray *foldersWithNewMessages;
@property (nonatomic, strong) NSMutableArray *updateCountOperations;
@property (nonatomic, strong) NSMutableArray *missingFolderPaths;
@property (nonatomic, strong) NSMutableIndexSet *hiddenConversations;
@property (nonatomic, strong) NSMutableSet *updateCountScheduled;
@property (nonatomic, strong) NSMutableArray *messageForRowIDOperations;
@property (nonatomic, strong) NSMutableDictionary *messagesWithModifiedFlags;

@property (nonatomic, strong) NSMutableArray *remoteSearchUIDsForFolder;
@property (nonatomic, strong) NSMutableArray *remoteSearchConversations;
@property (nonatomic, strong) NSMutableArray *remoteSearchFolderSynchronizers;
@property (nonatomic, strong) NSArray *searchTerms;

@property (nonatomic, strong) NSMutableSet *searchSuggestionsSubjects;
@property (nonatomic, strong) NSMutableSet *searchSuggestionsPeopleByDisplayName;
@property (nonatomic, strong) NSMutableSet *searchSuggestionsPeopleByMailbox;
@property (nonatomic, strong) NSMutableSet *searchSuggestionsMailboxes;
@property (nonatomic, strong) NSMutableSet *searchSuggestionsTerms;
@property (nonatomic, strong) NSMutableArray *currentSearchResult;

@property (nonatomic, assign) int missingFolderIndex;
@property (nonatomic, assign) int savingLocalDraft;

@property (nonatomic, assign) unsigned int maximumParallelConnections;

@property (nonatomic, strong) NSMutableArray *folders;
@property (nonatomic, strong) NSMutableArray *nonSelectableFolders;
@property (nonatomic, strong) NSMutableSet *foldersSet;

@property (nonatomic, strong) PSTConversationFetchOperation *conversationsOperation;
@property (nonatomic, strong) PSTStorageOperation *refreshStoreFolderOperation;
@property (nonatomic, strong) PSTStorageOperation *backgroundCompletion;
@property (nonatomic, strong) PSTSearchOperation *currentSearchOperation;

@property (nonatomic, strong) PSTActivity *foldersRequestActivity;
@property (nonatomic, strong) PSTActivity *namespaceRequestActivity;
@property (nonatomic, strong) PSTActivity *capabilityRequestActivity;
@property (nonatomic, strong) PSTActivity *refreshFoldersRequestActivity;
@property (nonatomic, strong) PSTActivity *refreshStoreFolderOperationActivity;
@property (nonatomic, strong) PSTActivity *loadActivity;
@property (nonatomic, strong) PSTActivity *searchActivity;

@property (nonatomic, strong) NSMutableSet *pendingSendMessages;

@property (nonatomic, assign) NSTimeInterval lastRefreshTimestamp;

@property (nonatomic, assign) NSTimeInterval lastPendingMessagesRequestDate;

@property (nonatomic, strong) MCOIMAPFolder *inboxFolder;
@property (nonatomic, strong) MCOIMAPFolder *trashFolder;
@property (nonatomic, strong) MCOIMAPFolder *sentMailFolder;
@property (nonatomic, strong) MCOIMAPFolder *allMailFolder;
@property (nonatomic, strong) MCOIMAPFolder *starredFolder;
@property (nonatomic, strong) MCOIMAPFolder *draftsFolder;
@property (nonatomic, strong) MCOIMAPFolder *importantFolder;
@property (nonatomic, strong) MCOIMAPFolder *spamFolder;

@property (nonatomic, assign) int foldersIndex;

@property (nonatomic, strong) RACSubject *attachmentsSubject;
@property (nonatomic, strong) RACSubject *facebookSubject;
@property (nonatomic, strong) RACSubject *twitterSubject;

@end

@implementation PSTIMAPAccountSynchronizer {
	struct {
		unsigned int fullConversationLoadAfterPartial:1;
		unsigned int fullSearchAfterPartial:1;
		unsigned int cancelling:1;
		unsigned int performingRemoteSearch:1;
		unsigned int searching:1;
		unsigned int updateStarredCountScheduled:1;
		unsigned int updatePriorityInboxUnseenCountScheduled:1;
		unsigned int checkedMissingFolders:1;
		unsigned int firstRefreshFolderDone:1;
		unsigned int hasNamespace:1;
		unsigned int namespacePrefixForced:1;
		unsigned int collectNotificationsScheduled:1;
		unsigned int hasMissingFolders:1;
		unsigned int sent:1;
		unsigned int trash:1;
		unsigned int draft:1;
	} _synchronizerFlags; // 16 bytes
}

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	
	_folderSynchronizers = [NSMutableDictionary dictionary];
	_foldersInSync = [NSMutableSet set];
	_updateFolderOperations = [NSMutableArray array];
	_attachmentSaveFilenames = [NSMutableDictionary dictionary];
	_attachmentQueue = [NSMutableArray array];
	_foldersWithNewMessages = [NSMutableArray array];
	_folders = [NSMutableArray array];
	_updateCountOperations = [NSMutableArray array];
	_updateCountScheduled = [NSMutableSet set];
	_hiddenConversations = [NSMutableIndexSet indexSet];
	_messagesWithModifiedFlags = [[NSMutableDictionary alloc] init];
	_maximumParallelConnections = 5;	//DEBUG
	
	_attachmentsSubject = [RACSubject subject];
	_facebookSubject = [RACSubject subject];
	_twitterSubject = [RACSubject subject];

	@weakify(self);
	[NSNotificationCenter.defaultCenter addObserverForName:PSTMailAccountActionStepCountUpdated object:nil queue:nil usingBlock:^(NSNotification *note) {
		@strongify(self);
		if (self.selectedNextSteps) {
			[self _cancelConversationsOperation];
			[self fetchPersistedConversations];
		}
	}];
	
	return self;
}

- (void)dealloc {
//	[self _cancelConversationsOperation];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_requestPendingMessages) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[NSNotificationCenter.defaultCenter removeObserver:self];
	for (PSTIMAPFolderSynchronizer *synchronizer in[self.folderSynchronizers allValues]) {
		[synchronizer cancel];
		[self _removeSynchronizerForFolder:synchronizer.folder];
	}
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"savingDrafts"] == NO) {
		if ([keyPath isEqualToString:@"error"]) {
			return;
		}
		PSTPropogateValueForKey(keyPath, { });
	}
	PSTPropogateValueForKey(self.syncing, { });
}

#pragma mark Storage

- (RACSignal *)_openIfNeeded {
	if (self.databaseController != nil) {
		return [RACSignal return:@(YES)];
	}
	self.databaseController = [[PSTDatabaseController alloc] initWithPath:[[NSString stringWithFormat:@"~/Library/Application Support/DotMail/%@.dotmaildb", self.email] stringByExpandingTildeInPath]];
	self.databaseController.email = self.email;
	return [[self.databaseController open]flattenMap:^RACStream *(id value) {
		return [RACSignal return:@(YES)];
	}];
}

- (void)_closeStorage {
	[self.databaseController close];
}

- (void)_close {
	[NSNotificationCenter.defaultCenter removeObserver:self name:PSTStorageGotModifiedConversationNotification object:self.databaseController];
	self.databaseController = nil;
}

- (RACSignal *)saveState {
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		for (PSTIMAPFolderSynchronizer *folderSynchronizer in [self.folderSynchronizers allValues]) {
			[folderSynchronizer cancel];
		}
		[self _cancelConversationsOperation];
		[self _closeStorage];
		for (PSTStorageOperation *op in self.updateCountOperations) {
			[op cancel];
		}
		[self.updateCountOperations removeAllObjects];
		[self.databaseController cancelAllOperations];
		return nil;
	}];
}

- (RACSignal *)saveMessage:(id)message {
//	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
//		[self attemptToSaveMessageToLocalDrafts:message];
//		if (![self.foldersSet containsObject:self.draftsFolder.path]) {
//			<#statements#>
//		} else {
//			[self _updateCountForFolder:self.draftsFolder];
//			PSTIMAPFolderSynchronizer *draftsSynchronizer = [self.folderSynchronizers objectForKey:self.draftsFolder.path];
//			
//		}
//		return nil;
//	}];
	return nil;
}

- (RACSignal *)twitterMessagesSignal {
	return _twitterSubject;
}

- (RACSignal *)facebookMessagesSignal {
	return _facebookSubject;
}

- (RACSignal*)attachmentsSignal {
	return _attachmentsSubject;
}

- (void)beginConversationUpdates {
	[self.databaseController beginConversationUpdates];
}

- (void)endConversationUpdates {
	[self.databaseController endConversationUpdates];
}

- (void)addModifiedMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	NSMutableArray *entry = self.messagesWithModifiedFlags[path];
	if (!entry) {
		entry = @[].mutableCopy;
		[self.messagesWithModifiedFlags setObject:entry forKey:path];
	}
	[entry addObject:message];
	[self _scheduleModifiedMessages];
}

- (void)_scheduleModifiedMessages {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_scheduleModifiedMessagesAfterDelay) object:nil];
	[self performSelector:@selector(_scheduleModifiedMessagesAfterDelay) withObject:self afterDelay:0];
}

- (void)_scheduleModifiedMessagesAfterDelay {
	if (self.messagesWithModifiedFlags != nil) {
		[[self.databaseController updateMessagesFlagsFromUserOperation:self.messagesWithModifiedFlags]start:^{
			for (NSString *path in self.messagesWithModifiedFlags.allKeys) {
				[self.folderSynchronizers[path] syncWithOptions:PSTFolderSynchronizerOptionPushModifiedMessages];
				[self.messagesWithModifiedFlags removeObjectForKey:path];
			}
		}];
	}
}

#pragma mark Sequence Count

- (void)setRequestBySequenceCount:(NSUInteger)requestBySequenceCount {
	_requestBySequenceCount = requestBySequenceCount;
	for (PSTIMAPFolderSynchronizer *folderSynchronizer in[self.folderSynchronizers allValues]) {
//		[folderSynchronizer setRequestBySequenceCount:requestBySequenceCount];
	}
}

- (void)waitUntilAllOperationsHaveFinished {
	[self.databaseController waitUntilAllOperationsHaveFinished];
	[self _close];
}

#pragma mark Close Sync

- (void)invalidateSynchronizer {
	[PSTIMAPAccountSynchronizer cancelPreviousPerformRequestsWithTarget:self];
	[NSNotificationCenter.defaultCenter removeObserver:self];
	
	for (PSTIMAPFolderSynchronizer *folderSynchronizer in[self.folderSynchronizers allValues]) {
		[self _removeSynchronizerForFolder:folderSynchronizer.folder];
		[self _removeSyncingFolder:folderSynchronizer.folder];
	}
}

#pragma mark - Create Account

- (void)_createAccountIfNeeded {
	if (self.session == nil) {
		self.session = [[MCOIMAPSession alloc] init];
		[self.session setCheckCertificateEnabled:NO];
		[self.session setHostname:self.host];
		[self.session setPort:self.port];
		[self.session setUsername:self.login];
		[self.session setPassword:self.password];
		[self.session setConnectionType:self.connectionType];
		[self.session setDm_XListMapping:self.xListMapping];
		[self.session setMaximumConnections:self.maximumParallelConnections];
		[self _setupFoldersSync];
		[self.delegate accountSynchronizerDidSetupAccount:self];
	}
}

#pragma mark - Disconnect

- (void)_disconnect {
	self.session = nil;
}

- (void)removeConversation:(PSTConversation *)conversation {
	NSMutableArray *revisedConversations = @[].mutableCopy;
	PSTPropogateValueForKey(self.currentConversations, {
		for (PSTConversation *conversation in self.currentConversations) {
			if (conversation.conversationID != conversation.conversationID) {
				[revisedConversations addObject:revisedConversations];
			}
		}
		self.currentConversations = revisedConversations;
	});
	
	[self _cancelConversationsOperation];
	[self fetchPersistedConversations];
}

- (void)addMessagesToDelete:(NSArray *)messages {
	[[self.databaseController markMessagesAsDeletedOperation:messages withPaths:PSTPathsForMessages(messages)] start:^{
		[[self.folderSynchronizers[@"INBOX"] syncWithOptions:PSTFolderSynchronizerOptionPushModifiedMessages]subscribeCompleted:^{
			
		}];
	}];
}

- (void)cancelRemoteSearch {
	if (self.selectedFolder == nil) {
		return;
	}
	_synchronizerFlags.performingRemoteSearch = NO;
	[_remoteSearchUIDsForFolder removeAllObjects];
	[_remoteSearchConversations removeAllObjects];
	[_remoteSearchFolderSynchronizers makeObjectsPerformSelector:@selector(cancelRemoteSearch)];
	[_remoteSearchFolderSynchronizers removeAllObjects];
}

- (void)_cancelCurrentSearchOperation {
	_synchronizerFlags.searching = NO;
	[PSTActivityManager.sharedManager removeActivity:self.searchActivity];
	self.searchActivity = nil;
	[self.currentSearchOperation cancel];
	self.currentSearchOperation = nil;
}

- (void)cancelSearch {
	if (_currentSearchOperation) {
		[self _cancelCurrentSearchOperation];
	}
	_searchTerms = nil;
	if (self.currentSearchResult == nil) {
		return;
	}
	PSTPropogateValueForKey(self.currentSearchResult, {
		self.currentSearchResult = nil;
	});
}

- (NSArray *)searchSuggestionsTerms {
	return _searchSuggestionsTerms.allObjects;
}

- (void)searchWithTerms:(NSArray *)terms complete:(BOOL)complete searchStringToComplete:(NSAttributedString *)attributedString {
	if (_currentSearchOperation) {
		[self _cancelCurrentSearchOperation];
	}
	_synchronizerFlags.fullSearchAfterPartial = NO;
	_synchronizerFlags.searching = YES;
	PSTPropogateValueForKey(self.currentSearchResult, {
		self.currentSearchResult = @[].mutableCopy;
	});
	PSTPropogateValueForKey(self.searchSuggestions, {
		_searchSuggestionsSubjects = nil;
		_searchSuggestionsPeopleByDisplayName = nil;
		_searchSuggestionsPeopleByMailbox = nil;
		_searchSuggestionsMailboxes = nil;
	});
	[self.hiddenConversations removeAllIndexes];
	self.searchTerms = terms;
	if ([self isSelectedFolderAvailable:_allMailFolder]) {
		_currentSearchOperation = [self.databaseController searchConversationsOperationWithTerms:terms kind:0x10 folder:self.allMailFolder otherFolder:self.inboxFolder limit:0x64];
	} else {
		_currentSearchOperation = [self.databaseController searchConversationsOperationWithTerms:terms kind:0x10 notInTrashFolder:self.trashFolder otherFolder:self.inboxFolder limit:0x64];
	}
	[_currentSearchOperation setSearchStringToComplete:attributedString];
	[_currentSearchOperation setNeedsSuggestions:complete];
	[_currentSearchOperation setMainFolders:[self _mainFolders]];
	[_currentSearchOperation start:^(BOOL hasSuggestions, NSMutableSet *bysubject, NSMutableSet *bymailbox, NSMutableSet *byname) {
		if (hasSuggestions) {
			PSTPropogateValueForKey(self.searchSuggestions, {
				_searchSuggestionsSubjects = bysubject;
				_searchSuggestionsPeopleByMailbox = bymailbox;
				_searchSuggestionsPeopleByDisplayName = byname;
			});
		}
	}];
}

- (NSArray *)searchSuggestions {
	return @[];
}

- (NSDictionary *)_mainFolders {
	NSMutableDictionary *result = @{}.mutableCopy;
	if (_inboxFolder) {
		[result setObject:_inboxFolder forKey:@"inbox"];
	}
	if (_allMailFolder) {
		[result setObject:_allMailFolder forKey:@"archive"];
	}
	if (_sentMailFolder) {
		[result setObject:_sentMailFolder forKey:@"sent"];
	}
	if (_draftsFolder) {
		[result setObject:_draftsFolder forKey:@"draft"];
	}
	if (_trashFolder) {
		[result setObject:_trashFolder forKey:@"trash"];
	}
	if (_spamFolder) {
		[result setObject:_spamFolder forKey:@"spam"];
	}
	if (_importantFolder) {
		[result setObject:_importantFolder forKey:@"important"];
	}
	return result;
}

- (void)refreshStarred {
	[self fetchPersistedConversations];
}

#pragma mark - Sync

- (RACSignal *)sync {
	self.loading = YES;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshSync) object:nil];

	if (!self.delegate || !self.password) {
		return RACSignal.empty;
	} 	
	if (!_synchronizerFlags.cancelling) {
		return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
			[[self _loadIfNeeded]subscribeCompleted:^{
				[[self _refreshFolders]subscribeCompleted:^{
					__block uint iterations = 0;
					NSArray *dividedFolders = nil;
					PSTPreferentialArrayDivide(&dividedFolders, self.folders, self.folders.count);
					[[RACScheduler scheduler] scheduleRecursiveBlock:^(void(^reschedule)()) {
						[[self _dispatchSynchronizersForFolders:dividedFolders index:iterations options:PSTFolderSynchronizerOptionNone]subscribeCompleted:^{
							if ((dividedFolders.count - 1) > iterations) {
								iterations++;
								reschedule();
							} else {
								self.loading = NO;
								[subscriber sendCompleted];
							}
						}];
					}];
				}];
			}];
			return nil;
		}];
	}
	[self _checkCancelFinished];
	return nil;
}

- (RACSignal *)refreshSync {
	self.loading = YES;
	if (!self.delegate || !self.password) {
		return [RACSignal error:[NSError errorWithDomain:PSTErrorDomain code:PSTErrorCannotAuthenticateWithoutPassword userInfo:nil]];
	}
	if (!_synchronizerFlags.cancelling) {
		return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
			[[self _loadIfNeeded]subscribeCompleted:^{
				[[self _refreshFolders]subscribeCompleted:^{
					__block uint iterations = 0;
					NSArray *dividedFolders = nil;
					PSTPreferentialArrayDivide(&dividedFolders, self.folders, roundtol(self.folders.count/3));
					
					[[RACScheduler scheduler] scheduleRecursiveBlock:^(void(^reschedule)()) {
						[[self _dispatchSynchronizersForFolders:dividedFolders index:iterations options:PSTFolderSynchronizerOptionRefresh]subscribeCompleted:^{
							if ((dividedFolders.count - 1) > iterations) {
								iterations++;
								reschedule();
							} else {
								double delayInSeconds = 180.0;
								dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
								dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
									[[self refreshSync]subscribe:subscriber];
								});
							}
						}];
					}];
				}];
			}];
			return nil;
		}];
	}
	[self _checkCancelFinished];
	return nil;
}

- (RACSignal *)_dispatchSynchronizersForFolders:(NSArray *)dividedFolders index:(NSUInteger)index options:(PSTFolderSynchronizerOptions)options {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		[[self _openIfNeeded] subscribeNext:^(id x) {
			[[RACSignal merge:PSTArrayMap(dividedFolders[index], ^id(MCOIMAPFolder *folder) {
				PSTIMAPFolderSynchronizer *synchronizer = self.folderSynchronizers[folder.path];
				if (!synchronizer) {
					return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
						[subscriber sendCompleted];
						return nil;
					}];
				}
				return [[[[synchronizer syncWithOptions:options] deliverOn:RACScheduler.mainThreadScheduler]doCompleted:^{
					[self _updateCountForFolder:synchronizer.folder];
					if (synchronizer.folder == self.selectedFolder) {
						self.loading = NO;
						[self folderSynchronizerDidUpdateMessageList:synchronizer];
					}
				}] doNext:^(PSTIMAPFolderSynchronizer *x) {
					[self _updateCountForFolder:x.folder];
					[self folderSynchronizerNeedsCoalesceNotifications:x];
					if ([x.folder.path isEqualToString:self.selectedFolder.path]) {
						self.loading = NO;
						[self folderSynchronizerDidUpdateMessageList:x];
					}
				}];
			})] subscribe:subscriber];
		}];
		return nil;
	}];
}

- (BOOL)isSelectedFolderAvailable:(MCOIMAPFolder *)folder {
	BOOL result = YES;
	if (self.foldersSet != nil) {
		result = [self.foldersSet containsObject:folder.path];
	}
	return result;
}

- (BOOL)hasDataForMessage:(MCOIMAPMessage*)message atPath:(NSString *)path {
	return [self.databaseController hasDataForMessage:message atPath:path];
}

- (NSData *)dataForMessage:(MCOIMAPMessage *)attachment atPath:(NSString *)path {
	return [self.databaseController dataForMessage:attachment atPath:path];
}

- (BOOL)hasDataForAttachment:(MCOAbstractPart*)message atPath:(NSString *)path {
	return [self.databaseController hasDataForAttachment:message atPath:path];
}

- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment onMessage:(MCOIMAPMessage *)message atPath:(NSString *)path {
	return [self.databaseController dataForAttachment:attachment onMessage:message atPath:path];
}

- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path {
	return [self.databaseController dataForAttachment:attachment atPath:path];
}

- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	return [self.databaseController previewForMessage:message atPath:path];
}

#pragma mark - PSTStorageOperationDelegate

- (void)storageOperationDidFinish:(PSTStorageOperation *)op {
	if ([self.updateCountOperations containsObject:op]) {
		[self _updateCountDone:(PSTUpdateCountOperation *)op];
	}
}

- (void)storageOperationDidUpdateState:(PSTStorageOperation *)op {
	PSTPropogateValueForKey(self.currentSearchResult, {
		NSMutableArray *result = @[].mutableCopy;
		for (PSTConversation *convo in ((PSTSearchOperation *)_currentSearchOperation).conversations) {
			if (![self.hiddenConversations containsIndex:convo.conversationID]) {
				[result addObject:convo];
				[convo setStorage:self.databaseController];
			}
		}
		self.currentSearchResult = result;
	});
}

- (NSUInteger)countForFolder:(MCOIMAPFolder *)folder {
	return [self.databaseController cachedCountForFolder:folder];
}

- (NSUInteger)unseenCountForFolder:(MCOIMAPFolder *)folder {
	return [self.databaseController cachedUnseenCountForFolder:folder];
}

- (NSUInteger)countForStarred {
	return [self.databaseController cachedCountForStarredNotInTrashFolder:self.trashFolder];
}

- (NSUInteger)countForNextSteps {
	return [self.databaseController cachedCountForNextStepsNotInTrashFolderPath:self.trashFolder];
}

- (void)cancel {
	_synchronizerFlags.cancelling = YES;
	[self.databaseController cancelAllOperations];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshSync) object:nil];
	[self _checkCancelFinished];
}

- (RACSignal *)_startRequestFolders {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		_synchronizerFlags.hasMissingFolders = NO;
		_synchronizerFlags.firstRefreshFolderDone = YES;
		self.foldersRequestActivity = [PSTActivity activityWithDescription:@"Fetching Folders..." forEmail:self.email];
		[[self.session fetchAllFoldersOperation]start:^(NSError *error, NSArray *folders) {
			@strongify(self);
			if (error) {
				[subscriber sendError:error];
				[subscriber sendCompleted];
				[PSTActivityManager.sharedManager removeActivity:self.foldersRequestActivity];
				return;
			}
			[PSTActivityManager.sharedManager removeActivity:self.foldersRequestActivity];
			self.foldersRequestActivity = nil;
			self.xListMapping = [[MCOIMAPSession XListMappingWithFolders:folders] copy];
			[self _setupFolders];
			if (self.xListMapping.count != 0) {
				[self.delegate accountSynchronizerDidUpdateXListMapping:self];
			}				
			folders = [folders arrayByAddingObject:[self.session inboxFolder]];
			
			[self _setFromFolders:folders];
			[[self.databaseController serializeFolders:folders] start:^{
				@strongify(self);
				dispatch_async(dispatch_get_main_queue(), ^{
					@strongify(self);
					[self _storeFoldersDone];
				});
			}];
			[subscriber sendNext:nil];
			[subscriber sendCompleted];
		}];
		return nil;
	}];
}

- (void)setSelectedFolder:(MCOIMAPFolder *)selectedFolder {
	if (self.selectedFolder == selectedFolder) {
		return;
	}
	[self.hiddenConversations removeAllIndexes];
	[super setSelectedFolder:selectedFolder];
	
	self.loading = YES;
	if ([self isSelectedStarred] == YES) {
		[self _cancelConversationsOperation];
		[self fetchPersistedConversations];
	}
	else {
		[self fetchPersistedConversations];
	}
}

- (void)fetchPersistedConversations {
	NSUInteger limit = 0;
	if (self.currentConversations.count == 0) {
		limit = 32;
	}
	[self _requestConversationFromStorageWithLimit:limit fullLoadAfterPartial:NO];
}

- (RACSignal *)_loadIfNeeded {
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		if (self.databaseController != nil) {
			[subscriber sendNext:nil];
			[subscriber sendCompleted];
			return nil;
		}
		[[[self _openIfNeeded]deliverOn:[RACScheduler mainThreadScheduler]] subscribeCompleted:^{
			[self _createAccountIfNeeded];
			[subscriber sendNext:nil];
			[subscriber sendCompleted];
		}];
		
		return nil;
	}];
}

- (void)checkExistenceOfFolders {
	self.missingFolderPaths = nil;
	self.missingFolderPaths = [NSMutableArray array];
	[self checkExistenceOfFolder:_inboxFolder];
	[self checkExistenceOfFolder:_sentMailFolder];
	[self checkExistenceOfFolder:_starredFolder];
	[self checkExistenceOfFolder:_allMailFolder];
	[self checkExistenceOfFolder:_trashFolder];
	[self checkExistenceOfFolder:_draftsFolder];
	[self checkExistenceOfFolder:_spamFolder];
	[self checkExistenceOfFolder:_importantFolder];
}

- (void)_createMissingFolders {
	self.missingFolderIndex = 0;
	[self _createNextMissingFolder];
}

- (void)_createNextMissingFolder {
	if (self.missingFolderIndex >= self.missingFolderPaths.count) {
		[self _createMissingFoldersDone];
	}
	else {
		[[self.session createFolderOperation:[self.missingFolderPaths objectAtIndex:self.missingFolderIndex]]start:^(NSError *error) {
			self.missingFolderIndex += 1;
			[self _createNextMissingFolder];
		}];
	}
}

- (void)_createMissingFoldersDone {
	_synchronizerFlags.hasMissingFolders = YES;
	[self _startRequestFolders];
}

- (void)handleFolderSyncError:(MCOIMAPFolder *)folder {
	if (![folder.path isEqualToString:@"INBOX"]) {
		[self refreshSyncForFolder:folder];
	}
}

- (void)checkExistenceOfFolder:(MCOIMAPFolder *)folder {
	if (folder == nil) {
		return;
	}
	if ([self.foldersSet containsObject:folder.path]) {
		return;
	}
	[self.missingFolderPaths addObject:folder.path];
}

- (void)_requestConversationFromStorageWithLimit:(NSUInteger)limit fullLoadAfterPartial:(BOOL)fullLoadAfter {
	[self _cancelConversationsOperation];
	PSTLog(@"Request conversations");
	self.loadActivity = [PSTActivity activityWithDescription:@"Loading messages from database..." forEmail:self.email];
	if (self.selectedStarred == YES) {
		self.conversationsOperation = [self.databaseController starredConversationsOperationNotInTrashFolder:self.trashFolder];
	} else if (self.selectedNextSteps == YES) {
		self.conversationsOperation = [self.databaseController nextStepsConversationsOperationNotInTrashFolder:self.trashFolder];
	} else if (self.selectedFolder == self.allMailFolder) {
		self.conversationsOperation = [self.databaseController conversationsOperationForFolder:self.allMailFolder otherFolder:self.inboxFolder allMailFolder:self.allMailFolder];
	} else if (self.selectedFolder == self.trashFolder) {
		self.conversationsOperation = [self.databaseController trashConversationsOperationForFolder:self.selectedFolder];
	} else if ([self isSelectedFolderAvailable:self.selectedFolder]) {
		self.conversationsOperation = [self.databaseController conversationsOperationForFolder:self.selectedFolder trashFolder:self.trashFolder];
	} else {
		self.conversationsOperation = [self.databaseController conversationsOperationForFolder:self.selectedFolder trashFolder:self.trashFolder];
	}
	_synchronizerFlags.fullConversationLoadAfterPartial = fullLoadAfter;
	[self.conversationsOperation setLimit:limit];
	[self.conversationsOperation setDelegate:self];
	@weakify(self);
	[self.conversationsOperation start:^(NSArray *conversations) {
		@strongify(self);
		if (!self.isSelectedStarred) {
			NSMutableArray *newConversationsArray = [NSMutableArray array];
			for (PSTConversation *conversation in conversations) {
				if (![self.hiddenConversations containsIndex:conversation.conversationID]) {
					[newConversationsArray addObject:conversation];
					[conversation setStorage:self.databaseController];
				}
			}
			[self willChangeValueForKey:@"currentConversations"];
			self.currentConversations = newConversationsArray;
			[self didChangeValueForKey:@"currentConversations"];
			PSTLog(@"request conversation done: %lu messages", self.currentConversations.count);
			[PSTActivityManager.sharedManager removeActivity:self.loadActivity];
			self.loadActivity = nil;
			_synchronizerFlags.fullConversationLoadAfterPartial = NO;
			if (self.conversationsOperation.limit != 0) {
				[self _requestConversationFromStorageWithLimit:0 fullLoadAfterPartial:YES];
			}
			self.loading = NO;
		}
		self.loading = NO;
		if (self.selectedFolder != nil) {
			[[self.databaseController attachmentsForFolder:self.selectedFolder]start:^(NSArray *attachments) {
				@strongify(self);
				[self.attachmentsSubject sendNext:attachments];
			}];
		} else {
			[[self.databaseController attachmentsOperationNotInTrashFolder:self.trashFolder orAllMailFolder:self.allMailFolder]start:^(NSArray *attachments) {
				@strongify(self);
				[self.attachmentsSubject sendNext:attachments];
			}];
		}
		[[self.databaseController facebookNotificationsOperationNotInTrashFolder:self.inboxFolder] start:^(NSArray *conversations) {
			@strongify(self);
			[self.facebookSubject sendNext:conversations];
		}];
		
		[[self.databaseController twitterNotificationsOperationNotInTrashFolder:self.inboxFolder] start:^(NSArray *conversations) {
			@strongify(self);
			[self.twitterSubject sendNext:conversations];
		}];
	}];
}

- (void)_scheduleRefreshSync {
	if (_synchronizerFlags.cancelling) {
		return;
	}

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshSync) object:nil];
	[self refreshSync];
}

- (RACSignal *)_refreshFolders {
	for (MCOIMAPFolder *folder in self.folders) {
		[self _updateCountForFolder:folder];
	}
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		[[RACSignal merge:@[[self _startRequestNamespace], [self _startRequestCapability]]] subscribeCompleted:^{
			[[self _startRequestFolders]subscribeCompleted:^{
				[subscriber sendCompleted];
			}];
		}];
		
		return nil;
	}];
}

- (RACSignal *)_startRequestCapability {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		self.capabilityRequestActivity = [PSTActivity activityWithDescription:@"Requesting IMAP server capabilities" forEmail:self.email];
		[[self.session capabilityOperation]start:^(NSError *error, MCOIndexSet *capabilities) {
			if (error) {
				[subscriber sendError:error];
				[subscriber sendCompleted];
				[PSTActivityManager.sharedManager removeActivity:self.capabilityRequestActivity];
				return;
			}
			[PSTActivityManager.sharedManager removeActivity:self.capabilityRequestActivity];
			[subscriber sendNext:nil];
			[subscriber sendCompleted];
		}];
		return nil;
	}];	
}

- (RACSignal *)_startRequestNamespace {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		self.namespaceRequestActivity = [PSTActivity activityWithDescription:@"Requesting namespace" forEmail:self.email];
		[[self.session fetchNamespaceOperation]start:^(NSError *error, NSDictionary *namespaces) {
			if (error) {
				[subscriber sendError:error];
				[subscriber sendCompleted];
				[PSTActivityManager.sharedManager removeActivity:self.namespaceRequestActivity];
				return;
			}
			[PSTActivityManager.sharedManager removeActivity:self.namespaceRequestActivity];
			self.namespaceDelimiter = [[self.session defaultNamespace] mainDelimiter];
			if (self.namespacePrefix.length == 0) {
				PSTLog(@"prefix for %@: %@", self.login, [[self.session defaultNamespace] mainPrefix]);
				self.namespacePrefix = [[self.session defaultNamespace] mainPrefix];
				[self.delegate accountSynchronizerDidUpdateNamespace:self];
			}
			_synchronizerFlags.hasNamespace = YES;
			[subscriber sendNext:nil];
			[subscriber sendCompleted];
		}];
		return nil;
	}];
}

- (void)_setFromFolders:(NSArray *)fromFolders {
	self.folders = nil;
	self.nonSelectableFolders = nil;
	NSMutableArray *nonSelectableFolders = [NSMutableArray array];
	NSMutableArray *folders = [NSMutableArray array];
	NSMutableSet *uniquingSet = [NSMutableSet set];
	
	for (MCOIMAPFolder *folder in fromFolders) {
		if ([folder.path isEqualToString:@"[Gmail]"]) {
			continue;
		}
		if ((folder.flags & MCOIMAPFolderFlagNoSelect)) {
			[nonSelectableFolders addObject:folder];
		}
		else {
			if (![uniquingSet containsObject:folder.path]) {
				[folders addObject:folder];
				[uniquingSet addObject:folder.path];
			}
		}
	}
	self.folders = folders;
	self.nonSelectableFolders = nonSelectableFolders;
	[self _updateFolderSet];
}

- (void)_updateCountForFolder:(MCOIMAPFolder *)folder {
	[self.updateCountScheduled addObject:folder.path];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateCountAfterDelayForFolder:) object:folder];
	[self _updateCountAfterDelayForFolder:folder];
	if (self.starredFolder == nil) {
		_synchronizerFlags.updateStarredCountScheduled = YES;
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateCountForStarredAfterDelay:) object:nil];
		[self _updateCountForStarredAfterDelay:0];
	}
}

- (void)_updateCountAfterDelayForFolder:(MCOIMAPFolder *)folder {
	[self.updateCountScheduled removeObject:folder.path];
	if ([folder.path isEqualToString:self.inboxFolder.path]) {
		[self _updateCount:folder AndUnseen:YES];
		return;
	}
	[self _updateCount:folder AndUnseen:NO];
}

- (void)_updateCount:(MCOIMAPFolder *)folder AndUnseen:(BOOL)andUnseen {
	if (_synchronizerFlags.cancelling == NO) {
		PSTUpdateCountOperation *countop = nil;
		if (andUnseen) {
			countop = [self.databaseController updateUnreadCountOperation:folder];
		}
		else {
			countop = [self.databaseController updateCountOperation:folder];
		}
		if (countop == nil) {
			return;
		}
		else {
			[self.updateCountOperations addObject:countop];
			[countop setDelegate:self];
			[countop startRequest];
		}
	}
}

- (void)_setupFoldersSync {
	NSSet *foldersSet = [NSSet setWithArray:[self.folderSynchronizers allKeys]];
	NSMutableSet *mutableSet = [NSMutableSet set];
	for (MCOIMAPFolder *folder in self.folders) {
		[mutableSet addObject:folder.path];
	}
	NSSet *newSet = [foldersSet setByAddingObjectsFromSet:mutableSet];
	if (newSet.count != mutableSet.count || newSet.count != foldersSet.count || newSet.count == 0) {
	innerLogic:
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateCountForStarredAfterDelay) object:nil];
		for (PSTIMAPFolderSynchronizer *folderSynchronizer in[self.folderSynchronizers allValues]) {
			if (![mutableSet containsObject:folderSynchronizer.folder.path]) {
				[folderSynchronizer cancel];
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateCachedCountAfterDelayForFolder:) object:folderSynchronizer.folder];
				[self _removeSynchronizerForFolder:folderSynchronizer.folder];
				[self _removeSyncingFolder:folderSynchronizer.folder];
			}
		}
		[self _setupFolders];
		for (MCOIMAPFolder *folder in self.folders) {
			[self _addSynchronizerForFolder:folder];
		}
		[self _updateCountForStarred];
		[self _updateCountForNextSteps];
		for (MCOIMAPFolder *folder in self.folders) {
			[self _updateCachedCountForFolder:folder];
		}
	}
}

- (void)_setupFolders {
	_inboxFolder = nil;
	_sentMailFolder = nil;
	_starredFolder = nil;
	_trashFolder = nil;
	_draftsFolder = nil;
	_spamFolder = nil;
	_importantFolder = nil;
	_allMailFolder = nil;
	
	MCOMailProvider *provider = [[MCOMailProvidersManager sharedManager] providerForIdentifier:self.providerIdentifier];
	_inboxFolder = [self.session inboxFolder];
	
	if (provider == nil) {
		self.sentMailFolder = [self.session folderWithPath:@"sentmail"];
		self.starredFolder = [self.session folderWithPath:@"starred"];
		self.allMailFolder = [self.session folderWithPath:@"allmail"];
		self.trashFolder = [self.session folderWithPath:@"trash"];
		self.draftsFolder = [self.session folderWithPath:@"drafts"];
		self.spamFolder = [self.session folderWithPath:@"spam"];
		self.importantFolder = [self.session folderWithPath:@"important"];

	} else {
		self.sentMailFolder = [self.session sentMailFolderForProvider:provider];
		self.starredFolder = [self.session starredFolderForProvider:provider];
		self.allMailFolder = [self.session allMailFolderForProvider:provider];
		self.trashFolder = [self.session trashFolderForProvider:provider];
		self.draftsFolder = [self.session draftsFolderForProvider:provider];
		self.spamFolder = [self.session spamFolderForProvider:provider];
		self.importantFolder = [self.session importantFolderForProvider:provider];
	}
}

- (void)createFolder:(NSString *)folderPath {
	[[self.session createFolderOperation:folderPath]start:^(NSError *error) {
		if (error == nil) {
			[self _addFolder:folderPath];
			[self _updateFolderSet];
		}
	}];
}

- (void)deleteFolder:(NSString *)folderPath {
	[[self.session deleteFolderOperation:folderPath]start:^(NSError *error) {
		if (error == nil) {
			[self _deleteFolder:folderPath];
			[self _updateFolderSet];
		}
	}];
}

- (void)renameFolder:(MCOIMAPFolder *)folderToRename newName:(NSString *)newName {
	[[self.session renameFolderOperation:folderToRename.path otherName:newName]start:^(NSError *error) {
		if (error == nil) {
			[self _renameFolderAndSubFolders:folderToRename.path withNewPath:newName];
			[self _updateFolderSet];
		}
	}];
}

- (void)_updateFolderSet {
	self.foldersSet = nil;
	if (self.folders != nil) {
		self.foldersSet = [[NSMutableSet alloc] init];
		for (MCOIMAPFolder *folder in self.folders) {
			[self.foldersSet addObject:folder.path];
			[self _addSynchronizerForFolder:folder];
		}
	}
	[self.delegate accountSynchronizerFetchedFolders:self];
}

- (void)_incrementAndRefreshSync:(NSInteger)sIDX withFolders:(NSArray*)dividedFolders {
	if (sIDX == dividedFolders.count) {
		[NSNotificationCenter.defaultCenter postNotificationName:PSTMailAccountDidFinishSyncingAllFoldersNotification object:nil];
		[[[self.folderSynchronizers objectForKey:@"INBOX"]idle]subscribeNext:^(id x) {
			[self _dispatchSynchronizersForIDLE];
		}];
		return;
	}
	
	__block NSInteger completionCount = 0;
	__block NSInteger superIdx = sIDX;
	NSArray *dividedArray = dividedFolders[sIDX];
	
	for (__block NSInteger idx = 0; idx < dividedArray.count; idx++) {
		MCOIMAPFolder *folder = dividedArray[idx];
		PSTIMAPFolderSynchronizer *synchronizer = [self.folderSynchronizers objectForKey:folder.path];
		[[synchronizer syncWithOptions:PSTFolderSynchronizerOptionRefresh]subscribeNext:^(id x) {
			
		} error:^(NSError *error) {
			NSLog(@"Sync Error For Folder %@ - %@", folder, error);
		} completed:^{
			completionCount++;
			[self _updateCountForFolder:folder];
			if ([folder.path isEqualToString:self.selectedFolder.path]) {
				[self folderSynchronizerDidUpdateMessageList:synchronizer];
			}
			if (completionCount == [(NSArray *)dividedFolders[superIdx] count]) {
				superIdx++;
				completionCount = 0;
				[self _incrementAndRefreshSync:superIdx withFolders:dividedFolders];
				if (self.selectedFolder != nil) {
					[[self.databaseController attachmentsForFolder:self.selectedFolder]start:^(NSArray *attachments) {
						[self.attachmentsSubject sendNext:attachments];
					}];
				} else {
					[[self.databaseController attachmentsOperationNotInTrashFolder:self.trashFolder orAllMailFolder:self.allMailFolder]start:^(NSArray *attachments) {
						[self.attachmentsSubject sendNext:attachments];
					}];
				}
			}
		}];
	}
}

- (void)_dispatchSynchronizersForIDLE {
	PSTIMAPFolderSynchronizer *folderSyncer = [self.folderSynchronizers objectForKey:@"INBOX"];
	[[folderSyncer syncWithOptions:PSTFolderSynchronizerOptionIDLE]subscribeCompleted:^{
		[self folderSynchronizerDidUpdateMessageList:folderSyncer];
		[[folderSyncer idle]subscribeNext:^(id x) {
			[self _dispatchSynchronizersForIDLE];
		}];
	}];
}

- (void)_checkCancelFinished {
	if (self.foldersInSync.count != 0) {
		return;
	}
	[self setDelegate:nil];
	_synchronizerFlags.cancelling = NO;
}

- (void)_addsyncingFolder:(MCOIMAPFolder *)folder {
	[self.foldersInSync addObject:folder.path];
}

- (void)_addSynchronizerForFolder:(MCOIMAPFolder *)folder {
	if (folder == nil || [folder.path isEqualToString:self.allMailFolder.path]) {
		return;
	}
	[self _removeSynchronizerForFolder:folder];
	[self _removeSyncingFolder:folder];
	PSTIMAPFolderSynchronizer *folderSyncher = [[PSTIMAPFolderSynchronizer alloc] initWithSession:self.session forFolder:folder];
	folderSyncher.parentSynchronizer = self;
	[folderSyncher setDatabase:self.databaseController];
	[folderSyncher setTrashSynchronizer:(self.trashFolder == folder)];
	[folderSyncher setDraftSynchronizer:(self.draftsFolder == folder)];
	[self.folderSynchronizers setObject:folderSyncher forKey:folder.path];
	return;
}

- (void)_requestPendingMessagesAfterDelay {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_requestPendingMessages) object:nil];
	[self performSelector:@selector(_requestPendingMessages) withObject:nil afterDelay:0];
}

- (void)_updateCountForStarred {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateCountForStarredAfterDelay) object:nil];
	[self _updateCountForStarredAfterDelay:0];
}

- (void)_updateCountForStarredAfterDelay:(NSTimeInterval)delay {
	PSTUpdateCountOperation *countOperation = [self.databaseController updateCountForStarredNotInTrash:self.trashFolder];
	[self.updateCountOperations addObject:countOperation];
	[countOperation setDelegate:self];
	[countOperation performSelector:@selector(startRequest) withObject:nil afterDelay:delay];
}

- (void)_updateCountForNextSteps {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateCountForNextStepsAfterDelay) object:nil];
	[self _updateCountForNextStepsAfterDelay:0];
}

- (void)_updateCountForNextStepsAfterDelay:(NSTimeInterval)delay {
	PSTUpdateCountOperation *countOperation = [self.databaseController updateCountForNextStepsNotInTrash:self.trashFolder];
	[self.updateCountOperations addObject:countOperation];
	[countOperation setDelegate:self];
	[countOperation performSelector:@selector(startRequest) withObject:nil afterDelay:delay];
}

- (void)_updateCachedCountForFolder:(MCOIMAPFolder *)folder {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateCachedCountAfterDelayForFolder:) object:folder];
	[self _updateCachedCountAfterDelayForFolder:folder];
}

- (void)_updateCachedCountAfterDelayForFolder:(MCOIMAPFolder *)folder {
	if (![folder.path isEqualToString:self.inboxFolder.path]) {
		if (![folder.path isEqualToString:self.starredFolder.path]) {
			[self _updateCachedCount:folder unseen:YES];
			return;
		}
		[self _updateCachedCount:folder unseen:NO];
		return;
	}
	[self _updateCachedCount:folder unseen:NO];
	return;
}

- (void)_updateCachedCount:(MCOIMAPFolder *)folder unseen:(BOOL)andUnseen {
	if (!_synchronizerFlags.cancelling) {
		PSTUpdateCountOperation *op;
		if (andUnseen) {
			op = [self.databaseController updateCachedUnseenCountOperation:folder];
		}
		else {
			op = [self.databaseController updateCachedCountOperation:folder];
		}
		if (op != nil) {
			[self.updateCountOperations addObject:op];
			[op setDelegate:self];
			[op startRequest];
		}
	}
}

- (void)_cancelConversationsOperation {
	if (self.conversationsOperation == nil) {
		return;
	}
	[PSTActivityManager.sharedManager removeActivity:self.loadActivity];
	self.loadActivity = nil;
	
	[self.conversationsOperation cancel];
	self.conversationsOperation = nil;
}

- (void)_removeSynchronizerForFolder:(MCOIMAPFolder *)folder {
	if (folder == nil) {
		return;
	}
	PSTIMAPFolderSynchronizer *synchronizer = [self.folderSynchronizers objectForKey:folder.path];
	if (synchronizer != nil) {
		[synchronizer cancel];
	}
	[self.folderSynchronizers removeObjectForKey:folder.path];
}

- (void)_removeSyncingFolder:(MCOIMAPFolder *)folder {
	[self.foldersInSync removeObject:folder.path];
	PSTLog(@"removed folder %@", folder);
}

- (void)addFoldersWithPaths:(NSArray *)folderPaths {
	NSMutableArray *foldersToAdd = [[NSMutableArray alloc] init];
	for (NSString *folderPath in folderPaths) {
		[foldersToAdd addObject:[self.session folderWithPath:folderPath]];
	}
	self.folders = foldersToAdd;
	[self _setupFolders];
	[self _updateFolderSet];
	[self _setupFoldersSync];
}

- (void)_addFolder:(NSString *)folderPath {
	[self.folders addObject:[self.session folderWithPath:folderPath]];
	[self _updateFolderSet];
}

- (void)_deleteFolder:(NSString *)folderPath {
	if (self.folders.count == 0) {
		return [self _updateFolderSet];
	}
	for (int i = 0; i < self.folders.count; i++) {
		if (![[[self.folders objectAtIndex:i] path] isEqualToString:folderPath]) {
			continue;
		}
		[self.folders removeObjectAtIndex:i];
	}
	[self _updateFolderSet];
}

- (NSDictionary *)folderMappingWithoutTrash {
	NSMutableDictionary *retVal = [NSMutableDictionary dictionary];
	
	for (PSTIMAPFolderSynchronizer *folderSynchronizer in [self.folderSynchronizers allValues]) {
		retVal[folderSynchronizer.folder.path] = folderSynchronizer.folder;
	}
	[retVal removeObjectForKey:self.trashFolder.path];
	retVal[PSTSentMailFolderPathKey] = self.sentMailFolder.path;
	if (self.importantFolder.path != nil)
		retVal[PSTImportantFolderPathKey] = self.importantFolder.path;
	retVal[PSTSpamFolderPathKey] = self.spamFolder.path;
	retVal[PSTDraftsFolderPathKey] = self.draftsFolder.path;
	
	return retVal;
}

- (MCOIMAPFolder *)folderForPath:(NSString *)path {
	return [[self.folderSynchronizers objectForKey:path] folder];
}

- (void)stopSaveBeforeSendingMessageID:(NSString *)msgID { }

- (void)_draftSaved:(MCOIMAPMessage *)draft error:(NSError *)error {
	PSTLog(@"remote draft %@ saved", draft);
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:draft forKey:PSTMessageKey];
	if (error != nil) {
		[userInfo setObject:draft forKey:PSTErrorKey];
	}
	[NSNotificationCenter.defaultCenter postNotificationName:PSTMailAccountDraftSavedNotification object:self userInfo:userInfo];
}

#pragma mark - Operation Completion Handlers

- (void)_storeFoldersDone {
	[self.databaseController updateFolderIdentifiersCache];
	[self _setupFoldersSync];
	self.missingFolderPaths = nil;
	if (_synchronizerFlags.checkedMissingFolders == NO) {
		_synchronizerFlags.checkedMissingFolders = YES;
		[self checkExistenceOfFolders];
	}
	if (self.missingFolderPaths.count == 0) {
		self.missingFolderPaths = nil;
	} else {
		[self _createMissingFolders];
	}
	[self.delegate accountSynchronizerDidUpdateLabels:self];
}

- (void)_renameFolderAndSubFolders:(NSString *)folderPathToRename withNewPath:(NSString *)path {
	NSArray *folders = [self.folders copy];
	NSString *prefix = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%c", self.namespaceDelimiter]];
	for (MCOIMAPFolder *folder in folders) {
		if ([folder.path hasPrefix:prefix]) {
			NSString *newName = [folder.path substringFromIndex:[prefix length]];
			[self _renameFolder:folder newPathName:newName];
		}
		else {
			if ([folder.path isEqualToString:folderPathToRename]) {
				[self _renameFolder:folder newPathName:path];
			}
		}
	}
}

- (void)_renameFolder:(MCOIMAPFolder *)folder newPathName:(NSString *)newPathName {
	[[self.session renameFolderOperation:folder.path otherName:newPathName]start:^(NSError *error) {
		if (error == nil) {
			[self _renameFolderAndSubFolders:folder.path withNewPath:newPathName];
			[self _updateFolderSet];
		}
	}];
}

- (void)checkNotifications {
	if (_synchronizerFlags.cancelling == YES || _synchronizerFlags.collectNotificationsScheduled == YES) {
		return;
	}
	_synchronizerFlags.collectNotificationsScheduled = YES;
	[self performSelector:@selector(_coalesceNotifications) withObject:nil afterDelay:0];
}

- (void)_coalesceNotifications {
	PSTCoalesceNotificationOperation *collectNotificationsOperation = [self.databaseController coalesceNotificationsForFolder:self.inboxFolder];
	@weakify(self);
	[collectNotificationsOperation start:^(NSArray *messages, NSArray *conversationIDs) {
		@strongify(self);
		_synchronizerFlags.collectNotificationsScheduled = NO;
		if (messages.count != 0) {
			if ([self.selectedFolder.path isEqualToString:self.inboxFolder.path]) {
				[self fetchPersistedConversations];
			}
			[self.delegate accountSynchronizer:self postNotificationForMessages:messages conversationIDs:conversationIDs];
		}
	}];
}

- (void)_updateCountDone:(PSTUpdateCountOperation *)op {
	int doubleElse = 0;
	if (op.options & PSTUpdateCountOptionUpdateStarred) {
		[self _updateCountForStarredDone:op];
	} else { doubleElse++; }
	if (op.options & PSTUpdateCountOptionUpdateNextSteps) {
		[self _updateUnseenCountForNextSteps:op];
	} else { doubleElse++; }
	
	[self.updateCountOperations removeObject:op];

	if (doubleElse == 2) {
		for (PSTIMAPFolderSynchronizer *synchronizer in self.folderSynchronizers.allValues) {
			if ([synchronizer.folder.path isEqualToString:op.path]) {
				[self.databaseController invalidateCountForFolder:synchronizer.folder];
				[self.databaseController invalidateUnseenCountForFolder:synchronizer.folder];
				PSTLog(@"count updated %@ %lu %@", op.path, op.count, self.email);
				if (op.options & PSTUpdateCountOptionUpdateUnread) {
					[self.databaseController setCachedUnseenCount:op.count forPath:op.path];
				}
				else {
					[self.databaseController setCachedCount:op.count forPath:op.path];
				}
			}
		}
		[self.delegate accountSynchronizerDidUpdateCount:self];
	}
}

- (void)_updateCountForStarredDone:(PSTUpdateCountOperation *)op {
	[self.databaseController setCachedCountForStarred:op.count];
	[self.delegate accountSynchronizerDidUpdateCount:self];
}

- (void)_updateUnseenCountForNextSteps:(PSTUpdateCountOperation *)op {
	[self.databaseController setCachedCountForNextSteps:op.count];
	[self.delegate accountSynchronizerDidUpdateCount:self];
}

- (void)folderSynchronizerNeedsCoalesceNotifications:(PSTIMAPFolderSynchronizer *)synchronizer {
	if (![synchronizer.folder.path isEqualToString:self.inboxFolder.path]) {
		return;
	}
	[self checkNotifications];
}

- (BOOL)requestMessage:(MCOAbstractMessage *)message {
	BOOL result = NO;
	if ([message isKindOfClass:[MCOIMAPMessage class]]) {
//			PSTIMAPFolderSynchronizer *synchronizer = [self.folderSynchronizers objectForKey:( (MCOIMAPMessage *)message ).folder.path];
//			result = [synchronizer requestMessage:message];
	}
	return result;
}


- (void)folderSynchronizerDidUpdateMessageList:(PSTIMAPFolderSynchronizer *)synchronizer {
	if (self.selectedFolder != nil) {
		if (synchronizer.folder.path != nil) {
			[self.hiddenConversations removeAllIndexes];
			[self fetchPersistedConversations];
		}
	}
}

#pragma mark - Private

static NSArray *PSTPathsForMessages(NSArray *messages) {
	NSMutableSet *result = [NSMutableSet set];
	for (PSTCachedMessage *message in messages) {
		[result addObject:message.folder];
	}
	return result.allObjects;
}

@end
