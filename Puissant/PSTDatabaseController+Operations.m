//
//  PSTAsyncStorage+Operations.m
//  Puissant
//
//  Created by Robert Widmann on 11/4/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTConversation.h"
#import "PSTConversationCache.h"
#import "PSTDatabaseController+Operations.h"
#import <ReactiveCocoa/EXTScope.h>

typedef NS_ENUM(int, PSTSearchOperationType) {
	PSTSearchOperationTypeAllMail,
	PSTSearchOperationTypeExcludeTrash
};

@implementation PSTDatabaseController (Operations)

- (NSArray *)messagesForConversationID:(NSUInteger)conversationID folder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder draftsFolderPath:(NSString *)draftsFolderPath sentMailFolderPath:(NSString *)sentMailFolderPath {
	return [self.databaseConnection messagesForConversationID:conversationID folder:folder otherFolder:otherFolder draftsFolderPath:draftsFolderPath sentMailFolderPath:sentMailFolderPath];
}

- (NSArray *)messagesForConversationID:(NSUInteger)conversationID mainFolder:(MCOIMAPFolder *)folder folders:(NSDictionary*)foldersDictionary draftsFolderPath:(NSString *)draftsFolderPath sentMailFolderPath:(NSString *)sentMailFolderPath {
	return [self.databaseConnection messagesForConversationID:conversationID mainFolder:folder folders:foldersDictionary draftsFolderPath:draftsFolderPath sentMailFolderPath:sentMailFolderPath];
}

- (void)setCachedCountForStarred:(NSUInteger)count {
	[self.countDatabaseConnection invalidateCountForStarred];
	[self.countDatabaseConnection setCachedCountForStarred:count];
}

- (void)invalidateCountForNextSteps {
	[self.countDatabaseConnection invalidateCountForNextSteps];
}

- (void)setCachedCountForNextSteps:(NSUInteger)count {
	[self.countDatabaseConnection invalidateCountForNextSteps];
	[self.countDatabaseConnection setCachedCountForNextSteps:count];
}

- (void)invalidateCountForFolder:(MCOIMAPFolder *)folder {
	[self.countDatabaseConnection invalidateCountForPath:folder.path];
}

- (void)invalidateUnseenCountForFolder:(MCOIMAPFolder *)folder {
	[self.countDatabaseConnection invalidateUnseenCountForPath:folder.path];
}

- (void)setCachedUnseenCount:(NSUInteger)count forPath:(NSString *)path {
	[self.countDatabaseConnection setCachedUnseenCount:count forPath:path];
}

- (void)setCachedCount:(NSUInteger)count forPath:(NSString *)path {
	[self.countDatabaseConnection setCachedCount:count forPath:path];
}

- (NSString *)previewForConversationCache:(PSTConversationCache *)cache {
	return [self.databaseConnection previewForConversationCache:cache];
}

- (BOOL)hasPreviewForConversationCache:(PSTConversationCache *)cache {
	return [self.databaseConnection hasPreviewForConversationCache:cache];
}

- (void)_prepareOperation:(PSTStorageOperation *)request {
	if ([request isKindOfClass:PSTUpdateCountOperation.class]) {
		[request setDatabase:self.countDatabaseConnection];
	}
	[request setStorage:self];
}

#pragma mark - Operation Alley

- (PSTCoalesceNotificationOperation *)coalesceNotificationsForFolder:(MCOIMAPFolder *)folder {
	if (folder == nil) {
		folder = [[MCOIMAPFolder alloc]init];
		folder.path = @"INBOX";
	}
	PSTCoalesceNotificationOperation *retVal = [[PSTCoalesceNotificationOperation alloc] init];
	[retVal setFolder:folder];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTRemoveLocalMessagesOperation *)removeLocalMessagesOperationForFolder:(MCOIMAPFolder *)folder {
	PSTRemoveLocalMessagesOperation *retVal = [[PSTRemoveLocalMessagesOperation alloc] init];
	[retVal setPath:folder.path];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTAddMessagesUIDsOperation *)addMessagesUIDsOperation:(NSIndexSet *)messages {
	PSTAddMessagesUIDsOperation *retVal = [[PSTAddMessagesUIDsOperation alloc] init];
	[retVal setMessages:messages];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTAddMessagesUIDsOperation *)addMessagesUIDsOperation:(NSIndexSet *)messages forFolder:(MCOIMAPFolder *)folder {
	PSTAddMessagesUIDsOperation *retVal = [[PSTAddMessagesUIDsOperation alloc] init];
	[retVal setMessages:messages];
	[retVal setFolder:folder];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTAddMessagesOperation *)addMessagesOperation:(NSArray *)messages markDeletedMessageID:(NSArray *)messageID folder:(MCOIMAPFolder *)folder isDraft:(BOOL)isDraft {
	PSTAddMessagesOperation *retVal = [[PSTAddMessagesOperation alloc] init];
	[retVal setPath:folder.path];
	[retVal setDraft:isDraft];
	[retVal setMessages:messages];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTIncompleteMessagesUIDOperation *)incompleteMessagesUIDOperationForFolder:(MCOIMAPFolder *)folder lastUID:(NSUInteger)lastUID limit:(NSUInteger)limit {
	PSTIncompleteMessagesUIDOperation *retVal = [[PSTIncompleteMessagesUIDOperation alloc] init];
	[retVal setPath:folder.path];
	[retVal setLimit:limit];
	[retVal setLastUID:lastUID];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTRemoveNonExistingMessagesOperation *)removeNonExistantMessagesOperation:(NSArray *)messages uidsSet:(NSIndexSet *)uidsSet folder:(MCOIMAPFolder *)folder {
	PSTRemoveNonExistingMessagesOperation *retVal = [[PSTRemoveNonExistingMessagesOperation alloc] init];
	[retVal setMessages:messages];
	[retVal setUidsSet:uidsSet];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTUpdateCountOperation *)updateCountForStarredNotInTrash:(MCOIMAPFolder *)trashFolder {
	PSTUpdateCountOperation *retVal = [[PSTUpdateCountOperation alloc] init];
	[retVal setOptions:(PSTUpdateCountOptionUpdateStarred)];
	[retVal setPath:trashFolder.path];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTUpdateCountOperation *)updateCountForNextStepsNotInTrash:(MCOIMAPFolder *)trashFolder {
	PSTUpdateCountOperation *retVal = [[PSTUpdateCountOperation alloc] init];
	[retVal setOptions:(PSTUpdateCountOptionUpdateNextSteps)];
	[retVal setPath:trashFolder.path];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTModifiedMessagesOperation *)modifiedMessagesOperationForFolder:(MCOIMAPFolder *)folder {
	PSTModifiedMessagesOperation *retVal = [[PSTModifiedMessagesOperation alloc] init];
	[retVal setFolder:folder];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTStorageOperation*)commitFlagsWithDirtyMessages:(NSArray*)modifiedMsgs {
	PSTCommitFlagsOperation *retVal = [[PSTCommitFlagsOperation alloc] init];
	[retVal setModifiedMessages:modifiedMsgs];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTStorageOperation *)addAttachmentOperation:(MCOIMAPPart *)attachment forMessage:(MCOIMAPMessage *)message inFolder:(MCOIMAPFolder *)folder data:(NSData *)data {
	PSTAddAttachmentOperation *retVal = [[PSTAddAttachmentOperation alloc] init];
	[retVal setMessage:message];
	[retVal setPartID:attachment.partID];
	[retVal setFilename:attachment.filename];
	[retVal setMimeType:attachment.mimeType];
	[retVal setPath:folder.path];
	[retVal setData:data];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTStorageOperation *)addMessageContentOperation:(MCOIMAPMessage *)message forFolder:(MCOIMAPFolder *)folder data:(NSData *)data {
	PSTAddMessageContentOperation *retVal = [[PSTAddMessageContentOperation alloc] init];
	[retVal setMessage:message];
	[retVal setData:data];
	[retVal setPath:folder.path];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTMessagesUIDOperation *)messagesOperationForFolder:(MCOIMAPFolder *)folder {
	PSTMessagesUIDOperation *retVal = [[PSTMessagesUIDOperation alloc] init];
	[retVal setPath:folder.path];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTUIDsNotInDatabaseOperation *)messagesUIDsNotInDatabase:(NSArray *)messageUIDs forFolder:(MCOIMAPFolder *)folder {
	PSTUIDsNotInDatabaseOperation *retVal = [[PSTUIDsNotInDatabaseOperation alloc] init];
	[retVal setPath:folder.path];
	[retVal setMessages:messageUIDs];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTStorageOperation *)removeMessageOperation:(MCOIMAPMessage *)message {
	PSTRemoveMessageOperation *retVal = [[PSTRemoveMessageOperation alloc] init];
	[retVal setMessage:message];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTLoadCachedFlagsOperation *)diffCacheFlagsOperationForFolder:(MCOIMAPFolder *)folder messages:(NSArray *)messages {
	PSTLoadCachedFlagsOperation *retVal = [[PSTLoadCachedFlagsOperation alloc] init];
	[retVal setPath:folder.path];
	[retVal setMessages:messages];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTLoadCachedFlagsOperation *)importCacheFlagsOperationForFolder:(MCOIMAPFolder *)folder {
	PSTLoadCachedFlagsOperation *retVal = [[PSTLoadCachedFlagsOperation alloc] init];
	[retVal setPath:folder.path];
	[retVal setImportMode:YES];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTUpdateMessagesFlagsFromServerOperation *)updateMessagesFlagsFromServerOperation:(NSArray *)messages atPath:(NSString *)path {
	PSTUpdateMessagesFlagsFromServerOperation *retVal = [[PSTUpdateMessagesFlagsFromServerOperation alloc] init];
	[retVal setMessages:messages];
	[retVal setPath:path];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTUpdateMessagesFlagsFromUserOperation *)updateMessagesFlagsFromUserOperation:(NSDictionary *)foldersToMessages {
	PSTUpdateMessagesFlagsFromUserOperation *retVal = [[PSTUpdateMessagesFlagsFromUserOperation alloc] init];
	[retVal setMessageMap:foldersToMessages];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTConversationFetchOperation *)conversationsOperationForFolder:(MCOIMAPFolder *)folder trashFolder:(MCOIMAPFolder *)trashFolder {
	PSTConversationFetchOperation *retVal = [[PSTConversationFetchOperation alloc] init];
	[retVal setFolder:folder];
	[retVal setMode:PSTConversationsFetchModeNormal];
	[retVal setTrashFolder:trashFolder];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTConversationFetchOperation *)trashConversationsOperationForFolder:(MCOIMAPFolder *)folder {
	PSTConversationFetchOperation *retVal = [[PSTConversationFetchOperation alloc] init];
	[retVal setMode:PSTConversationsFetchModeTrash];
	[retVal setFolder:folder];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTConversationFetchOperation *)unreadConversationsOperationInFolder:(MCOIMAPFolder *)folder trashFolder:(MCOIMAPFolder *)trashFolder {
	PSTConversationFetchOperation *retVal = [[PSTConversationFetchOperation alloc] init];
	[retVal setMode:PSTConversationsFetchModeUnread];
	[retVal setFolder:folder];
	[retVal setTrashFolder:trashFolder];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTConversationFetchOperation *)conversationsOperationForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder {
	return [self conversationsOperationForFolder:folder otherFolder:otherFolder allMailFolder:nil];
}

- (PSTConversationFetchOperation *)nextStepsConversationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder {
	PSTConversationFetchOperation *retVal = [[PSTConversationFetchOperation alloc] init];
	[retVal setTrashFolder:trashFolder];
	[retVal setMode:PSTConversationsFetchModeNextSteps];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTConversationFetchOperation *)starredConversationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder {
	PSTConversationFetchOperation *retVal = [[PSTConversationFetchOperation alloc] init];
	[retVal setTrashFolder:trashFolder];
	[retVal setMode:PSTConversationsFetchModeStarred];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTConversationFetchOperation *)conversationsOperationForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder allMailFolder:(MCOIMAPFolder *)allMailFolder {
	PSTConversationFetchOperation *retVal = [[PSTConversationFetchOperation alloc] init];
	[retVal setFolder:folder];
	[retVal setMode:(allMailFolder != nil ? PSTConversationsFetchModeAllMail : PSTConversationsFetchModeNormal)];
	[retVal setOtherFolder:otherFolder];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTConversationFetchOperation *)facebookNotificationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder {
	PSTConversationFetchOperation *retVal = [[PSTConversationFetchOperation alloc] init];
	[retVal setTrashFolder:trashFolder];
	[retVal setMode:PSTConversationFetchModeFacebookMessages];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTConversationFetchOperation *)twitterNotificationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder {
	PSTConversationFetchOperation *retVal = [[PSTConversationFetchOperation alloc] init];
	[retVal setTrashFolder:trashFolder];
	[retVal setMode:PSTConversationFetchModeTwitterMessages];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTAttachmentFetchOperation *)attachmentsForFolder:(MCOIMAPFolder *)selectedFolder {
	PSTAttachmentFetchOperation *retVal = [[PSTAttachmentFetchOperation alloc] init];
	[retVal setSelectedFolder:selectedFolder];
	[retVal setMode:PSTAttachmentFetchModeForFolder];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTAttachmentFetchOperation *)attachmentsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder orAllMailFolder:(MCOIMAPFolder*)allMailFolder {
	PSTAttachmentFetchOperation *retVal = [[PSTAttachmentFetchOperation alloc] init];
	[retVal setTrashFolder:trashFolder];
	[retVal setAllMailfolder:allMailFolder];
	[retVal setMode:PSTAttachmentFetchModeAll];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTSaveCachedFlagsOperation *)saveCacheFlagsOperationForFolder:(MCOIMAPFolder *)folder messages:(NSArray *)messages {
	PSTSaveCachedFlagsOperation *retVal = [[PSTSaveCachedFlagsOperation alloc] init];
	[retVal setPath:folder.path];
	[retVal setMessages:messages];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTMarkMessagesAsDeletedOperation *)markMessagesAsDeletedOperation:(NSArray *)messages withPaths:(NSArray *)paths {
	PSTMarkMessagesAsDeletedOperation *retVal = [[PSTMarkMessagesAsDeletedOperation alloc] init];
	[retVal setMessages:messages.copy];
	[retVal setPathsToCommit:paths];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTCommitFoldersOperation *)serializeFolders:(NSArray *)folders {
	PSTCommitFoldersOperation *retVal = [[PSTCommitFoldersOperation alloc] init];
	NSMutableArray *array = [NSMutableArray array];
	
	for (MCOIMAPFolder *folder in folders) {
		[array addObject:folder.path];
	}
	[retVal setFolderPaths:array];
	[self _prepareOperation:retVal];
	
	return retVal;
}

- (PSTLocalDraftMessagesOperation *)localDraftMessagesOperation:(MCOIMAPFolder *)folder {
	PSTLocalDraftMessagesOperation *retVal = [[PSTLocalDraftMessagesOperation alloc] init];
	[retVal setFolder:folder];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTUpdateCountOperation *)updateUnreadCountOperation:(MCOIMAPFolder *)folder {
	PSTUpdateCountOperation *retVal = [[PSTUpdateCountOperation alloc] init];
	[retVal setOptions:(PSTUpdateCountOptionUpdateUnread)];
	NSAssert(folder.path != nil, @"[folder path] cannot equal nil");
	[retVal setPath:folder.path];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTUpdateCountOperation *)updateCountOperation:(MCOIMAPFolder *)folder {
	PSTUpdateCountOperation *retVal = [[PSTUpdateCountOperation alloc] init];
	NSAssert(folder.path != nil, @"[folder path] cannot equal nil");
	[retVal setPath:folder.path];
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTSearchOperation *)searchConversationsOperationWithQuery:(NSString *)query {
	PSTSearchOperation *retVal = [[PSTSearchOperation alloc] init];
	retVal.query = query;
	[self _prepareOperation:retVal];
	return retVal;
}

- (PSTUpdateCountOperation *)updateCachedUnseenCountOperation:(MCOIMAPFolder *)folder {
	PSTUpdateCountOperation *result = [[PSTUpdateCountOperation alloc] init];
	[result setOptions:(PSTUpdateCountOptionUpdateCached | PSTUpdateCountOptionUpdateUnread)];
	NSAssert(folder.path != nil, @"[folder path] != nil");
	[result setPath:folder.path];
	[self _prepareOperation:result];
	return result;
}

- (PSTUpdateCountOperation *)updateCachedCountOperation:(MCOIMAPFolder *)folder {
	PSTUpdateCountOperation *result = [[PSTUpdateCountOperation alloc] init];
	[result setOptions:(PSTUpdateCountOptionUpdateCached)];
	NSAssert(folder.path != nil, @"[folder path] != nil");
	[result setPath:folder.path];
	[self _prepareOperation:result];
	return result;
}

- (PSTUpdateActionstepsOperation *)updateActionStepForConversation:(PSTConversation *)conversation actionStep:(PSTActionStepValue)actionStep {
	PSTUpdateActionstepsOperation *result = [[PSTUpdateActionstepsOperation alloc] init];
	[result setConversationID:conversation.conversationID];
	[result setActionStep:actionStep];
	[self _prepareOperation:result];
	return result;
}

@end