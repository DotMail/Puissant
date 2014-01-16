//
//  PSTAsyncStorage+Operations.h
//  Puissant
//
//  Created by Robert Widmann on 11/24/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTDatabaseController.h"
#import "PSTUpdateCountOperation.h"
#import "PSTConversationFetchOperation.h"
#import "PSTIncompleteMessagesUIDOperation.h"
#import "PSTRemoveMessageOperation.h"
#import "PSTCommitFoldersOperation.h"
#import "PSTModifiedMessagesOperation.h"
#import "PSTIndexedMapTable.h"
#import "PSTLevelDBMapTable.h"
#import "PSTDatabase.h"
#import "PSTLevelDBCache.h"
#import "PSTAddAttachmentOperation.h"
#import "PSTAddMessageContentOperation.h"
#import "PSTAddMessagesOperation.h"
#import "PSTAddMessagesUIDsOperation.h"
#import "PSTCoalesceNotificationOperation.h"
#import "PSTUIDsNotInDatabaseOperation.h"
#import "PSTRemoveMessageOperation.h"
#import "PSTMessagesUIDOperation.h"
#import "PSTRemoveNonExistingMessagesOperation.h"
#import "PSTLoadCacheOperation.h"
#import "PSTLoadCachedFlagsOperation.h"
#import "PSTUpdateMessagesFlagsFromServerOperation.h"
#import "PSTSaveCachedFlagsOperation.h"
#import "PSTLocalDraftMessagesOperation.h"
#import "PSTRemoveLocalMessagesOperation.h"
#import "PSTUpdateActionstepsOperation.h"
#import "PSTUpdateMessagesFlagsFromUserOperation.h"
#import "PSTAttachmentFetchOperation.h"
#import "PSTCommitFlagsOperation.h"
#import "PSTMarkMessagesAsDeletedOperation.h"
#import "PSTSearchOperation.h"

@class MCOIMAPPart;

@interface PSTDatabaseController (Operations)

/**
 * Invalidates, then sets, the cached count for the starred folder.
 */
- (void)setCachedCountForStarred:(NSUInteger)count;

/**
 * Invalidates, then sets, the cached count for the Next Steps folder.
 */
- (void)setCachedCountForNextSteps:(NSUInteger)count;

- (void)invalidateCountForFolder:(MCOIMAPFolder *)folder;
- (void)invalidateUnseenCountForFolder:(MCOIMAPFolder *)folder;

- (void)setCachedUnseenCount:(NSUInteger)count forPath:(NSString *)path;
- (void)setCachedCount:(NSUInteger)count forPath:(NSString *)path;

- (NSString *)previewForConversationCache:(PSTConversationCache *)cache;
- (BOOL)hasPreviewForConversationCache:(PSTConversationCache *)cache;

- (PSTMarkMessagesAsDeletedOperation *)markMessagesAsDeletedOperation:(NSArray *)messages withPaths:(NSArray *)paths;

- (PSTCommitFoldersOperation *)serializeFolders:(NSArray *)folders;

- (PSTUpdateCountOperation *)updateCountForStarredNotInTrash:(MCOIMAPFolder *)trashFolder;
- (PSTUpdateCountOperation *)updateCountForNextStepsNotInTrash:(MCOIMAPFolder *)trashFolder;
- (PSTModifiedMessagesOperation *)modifiedMessagesOperationForFolder:(MCOIMAPFolder *)folder;
- (PSTStorageOperation *)commitFlagsWithDirtyMessages:(NSArray*)modifiedMsgs;

- (PSTLocalDraftMessagesOperation *)localDraftMessagesOperation:(MCOIMAPFolder *)folder;

- (PSTLoadCachedFlagsOperation *)diffCacheFlagsOperationForFolder:(MCOIMAPFolder *)folder messages:(NSArray *)messages;
- (PSTLoadCachedFlagsOperation *)importCacheFlagsOperationForFolder:(MCOIMAPFolder *)folder;
- (PSTUpdateMessagesFlagsFromServerOperation *)updateMessagesFlagsFromServerOperation:(NSArray *)messages atPath:(NSString *)path;
- (PSTUpdateMessagesFlagsFromUserOperation *)updateMessagesFlagsFromUserOperation:(NSDictionary *)foldersToMessages;

- (PSTSaveCachedFlagsOperation *)saveCacheFlagsOperationForFolder:(MCOIMAPFolder *)folder messages:(NSArray *)messages;

- (PSTConversationFetchOperation *)conversationsOperationForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder;
- (PSTConversationFetchOperation *)nextStepsConversationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder;
- (PSTConversationFetchOperation *)conversationsOperationForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder allMailFolder:(MCOIMAPFolder *)allMailFolder;
- (PSTConversationFetchOperation *)conversationsOperationForFolder:(MCOIMAPFolder *)folder trashFolder:(MCOIMAPFolder *)trashFolder;
- (PSTConversationFetchOperation *)trashConversationsOperationForFolder:(MCOIMAPFolder *)folder;
- (PSTConversationFetchOperation *)starredConversationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder;

- (PSTConversationFetchOperation *)facebookNotificationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder;
- (PSTConversationFetchOperation *)twitterNotificationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder;

- (PSTAttachmentFetchOperation *)attachmentsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder orAllMailFolder:(MCOIMAPFolder*)allMailFolder;
- (PSTAttachmentFetchOperation *)attachmentsForFolder:(MCOIMAPFolder *)selectedFolder;

- (PSTStorageOperation *)addAttachmentOperation:(MCOIMAPPart *)attachment forMessage:(MCOIMAPMessage *)message inFolder:(MCOIMAPFolder *)folder data:(NSData *)data;
- (PSTStorageOperation *)addMessageContentOperation:(MCOIMAPMessage *)message forFolder:(MCOIMAPFolder *)folder data:(NSData *)data;
- (PSTAddMessagesOperation *)addMessagesOperation:(NSArray *)messages markDeletedMessageID:(NSArray *)messageID folder:(MCOIMAPFolder *)folder isDraft:(BOOL)isDraft;

- (PSTUpdateCountOperation *)updateUnreadCountOperation:(MCOIMAPFolder *)folder;
- (PSTUpdateCountOperation *)updateCountOperation:(MCOIMAPFolder *)folder;

- (PSTAddMessagesUIDsOperation *)addMessagesUIDsOperation:(NSIndexSet *)messages forFolder:(MCOIMAPFolder *)folder;

- (PSTIncompleteMessagesUIDOperation *)incompleteMessagesUIDOperationForFolder:(MCOIMAPFolder *)folder lastUID:(NSUInteger)lastUID limit:(NSUInteger)limit;
- (PSTCoalesceNotificationOperation *)coalesceNotificationsForFolder:(MCOIMAPFolder *)folder;
- (PSTRemoveLocalMessagesOperation *)removeLocalMessagesOperationForFolder:(MCOIMAPFolder *)folder;
- (PSTUIDsNotInDatabaseOperation *)messagesUIDsNotInDatabase:(NSArray *)messageUIDs forFolder:(MCOIMAPFolder *)folder;
- (PSTStorageOperation *)removeMessageOperation:(MCOIMAPMessage *)message;
- (PSTMessagesUIDOperation *)messagesOperationForFolder:(MCOIMAPFolder *)folder;
- (PSTRemoveNonExistingMessagesOperation *)removeNonExistantMessagesOperation:(NSArray *)messages uidsSet:(NSIndexSet *)uidsSet folder:(MCOIMAPFolder *)folder;

- (PSTSearchOperation *)searchConversationsOperationWithQuery:(NSString *)query;

- (PSTUpdateCountOperation *)updateCachedUnseenCountOperation:(MCOIMAPFolder *)folder;
- (PSTUpdateCountOperation *)updateCachedCountOperation:(MCOIMAPFolder *)folder;

- (PSTUpdateActionstepsOperation *)updateActionStepForConversation:(PSTConversation *)conversation actionStep:(PSTActionStepValue)actionStep;

- (NSArray *)messagesForConversationID:(NSUInteger)conversationID mainFolder:(MCOIMAPFolder *)folder folders:(NSDictionary *)foldersDictionary draftsFolderPath:(NSString *)draftsFolderPath sentMailFolderPath:(NSString *)sentMailFolderPath;
- (NSArray *)messagesForConversationID:(NSUInteger)conversationID folder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder draftsFolderPath:(NSString *)draftsFolderPath sentMailFolderPath:(NSString *)sentMailFolderPath;

@end