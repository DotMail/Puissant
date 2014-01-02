//
//  PSTMessageDatabase.h
//  DotMail
//
//  Created by Robert Widmann on 10/13/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

typedef NS_ENUM (NSInteger, PSTDatabaseType) {
	PSTDatabaseTypeSerial,		// Creates a database without WAL enabled and with a
								// high level of synchronization with the SQLite
								// database.
	PSTDatabaseTypeConcurrent	// Creates a database with WAL enabled and with a
								// normal level of synchronization with the SQLite
								// database
};

@class PSTLevelDBMapTable;
@class PSTIndexedMapTable;
@class PSTConversationCache;
@class LEPAbstractMessage;
@class PSTCache;
@class MCOIMAPMessage;
@class MCOIMAPFolder;
@class MCOAbstractMessage;
@class FMDatabase;
@class MCOIMAPMessagePart;
@class PSTCachedMessage;
@class PSTSerializableMessage;

@interface PSTDatabase : NSObject

/**
 * Initializes a database object with a given path and type.
 */
+ (instancetype)databaseForEmail:(NSString *)email withPath:(NSString *)path type:(PSTDatabaseType)type;

/**
 * Initializes the caches of a database.  This method is necessary for normal
 * operation of this object.
 */
- (void)initializeWithCachesForConversations:(PSTIndexedMapTable *)c messages:(PSTIndexedMapTable *)m previews:(PSTLevelDBMapTable *)p
										text:(PSTLevelDBMapTable *)t flags:(PSTLevelDBMapTable *)f labels:(PSTLevelDBMapTable *)l;

/**
 * Opens the database, creating it if necessary.
 */
- (BOOL)open;

/**
 * Closes the database and prepares the object for deallocation.
 */
- (void)close;

/**
 * Prepares the database for a new transaction.
 */
- (void)beginTransaction;

/**
 * Commits any changes from a transaction to the database.
 */
- (void)commit;

/**
 * Commits changes to message UIDs to the database.
 */
- (void)commitMessageUIDs;

@end

@interface PSTDatabase (PSTFoldersAndIdentifiers)

/**
 * Initializes a cache of folder identifiers.  This can dramatically speed up
 * future requests to the database.
 */
- (void)warmFolderIdentifiersCache;

/**
 * Initializes a cache of folder identifiers with a given mapping.
 */
- (void)defrostFolderIdentifiersWithDictionary:(NSDictionary *)foldersMapping;

/**
 * Inserts the given folder path into the database and creates a new entry in
 * the folder identifiers cache.
 */
- (NSUInteger)addFolder:(NSString *)path;

/**
 * Returns the count of messages for a given folder.
 */
- (NSUInteger)countOfMessagesAtPath:(NSString *)path;

/**
 * Returns the interned folder identifier for a given path;
 */
- (NSUInteger)identifierForFolderPath:(NSString *)path;

/**
 * Returns the folder path for a given interned folder identifier.
 */
- (NSString *)folderPathForIdentifier:(NSUInteger)identifier;

/**
 * Returns a copy of the mapping from folder paths to their interned folder
 * identifiers.
 */
- (NSDictionary *)foldersIdentifiersMap;

@end

@interface PSTDatabase (PSTMessageOperations)

/**
 * Adds a new message ID to the database, but also to the list of incomplete
 * messages so it can be retrieved later if content is not fetched for it.
 */
- (void)addMessageUID:(NSUInteger)uid forPath:(NSString *)path;

/**
 * Inserts a given message into the database.
 *
 * In addition to performing the necessary database updates required after
 * inserting the message, this method will update the conversations cache, and
 * attempt to insert the message into one of the conversation chains.  The
 * message is then removed from the list of incomplete messages;
 */
- (BOOL)addMessage:(MCOIMAPMessage *)message inFolder:(NSString *)path;

/**
 * Caches the data associated with the content of a message, then updates the
 * message's cached preview.
 */
- (void)setContent:(NSData *)data forMessage:(MCOAbstractMessage *)message inFolder:(NSString *)path;

/**
 * Caches an attachment for a message.
 */
- (void)addAttachment:(MCOAbstractMessage *)message inFolder:(NSString *)path partID:(NSString *)partID filename:(NSString *)filename data:(NSData *)data mimeType:(NSString *)mimeType;

- (NSIndexSet *)messagesUIDsNotInDatabase:(NSArray *)messages forPath:(NSString *)path;
- (NSIndexSet *)messagesUIDsSetForPath:(NSString *)path;

- (void)removeMessagesWithMessageID:(NSString *)msgID path:(NSString *)path;
- (void)removeLocalDraftMessageID:(NSString *)msgID path:(NSString *)path;
- (void)removeMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

- (NSData *)dataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path;
- (BOOL)hasDataForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

- (NSDictionary *)messagesNeedingNotificationForFolder:(MCOIMAPFolder *)folder;
- (NSDictionary *)messagesToModifyDictionaryForFolder:(MCOIMAPFolder *)folder;
- (NSArray *)diffCachedMessageFlagsForPath:(NSString *)path withMessage:(NSArray *)messages;

- (void)markMessageAsDeleted:(PSTSerializableMessage *)message;
- (void)removeLocalMessagesForFolderPath:(NSString *)path;

@end

@interface PSTDatabase (PSTMessageFlags)

- (void)cacheOriginalFlagsFromMessage:(MCOAbstractMessage *)message inFolder:(NSString *)folderPath;
- (void)cacheFlagsFromMessage:(MCOAbstractMessage *)message inFolder:(NSString *)path;
- (void)appendCachedMessageFlags:(NSMutableDictionary *)dict forPath:(NSString *)path;
- (void)saveCachedMessageFlags:(NSDictionary*)flags forPath:(NSString*)path;

- (BOOL)areFlagsChangedOnMessage:(MCOAbstractMessage *)message forPath:(NSString*)folderPath;
- (BOOL)updateMessageFlagsFromServer:(MCOAbstractMessage *)message forFolder:(NSString *)folderPath;
- (void)updateMessageFlagsFromUser:(MCOAbstractMessage *)message forFolder:(NSString *)folderPath;

- (void)commitMessageFlags:(MCOIMAPMessage *)message forFolder:(NSString *)folderPath DEPRECATED_ATTRIBUTE;

@end

@interface PSTDatabase (PSTIncompleteMessages)

/**
 * Sets a new cached last UID value for a given folder and stores it in the
 * database.
 */
- (NSUInteger)firstIncompleteUIDToFetch:(NSString *)path givenLastUID:(NSUInteger)lastUID;

/**
 * Returns the number of incomplete message UIDs stored in the database.
 */
- (NSUInteger)countOfIncompleteMessagesForFolderPath:(NSString *)path;

/**
 * Returns a subset of the cached UIDs for a given folder path.
 */
- (NSIndexSet *)incompleteMessagesSetForFolderPath:(NSString *)path lastUID:(NSUInteger)lastUID limit:(NSUInteger)limit;

@end

@interface PSTDatabase (PSTMessagePreviews)

- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;
- (BOOL)hasPreviewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

- (NSString *)previewForConversationCache:(PSTConversationCache *)cache;
- (BOOL)hasPreviewForConversationCache:(PSTConversationCache *)cache;

- (void)addPreviewObserverForUID:(NSString *)key withBlock:(void(^)(NSData *))block;
- (void)removePreviewObserverForUID:(NSString *)uid;

@end

@interface PSTDatabase (PSTCountOperations)

- (NSUInteger)countForPath:(NSString *)path;
- (void)setCount:(NSUInteger)count forPath:(NSString *)path;

- (NSUInteger)unseenCountForPath:(NSString *)path;
- (void)setUnseenCount:(NSUInteger)count forPath:(NSString *)path;

- (NSUInteger)countForStarredNotInTrashFolderPath:(NSString *)path;
- (void)setCountForStarred:(NSUInteger)count;

- (NSUInteger)countForNextStepsNotInTrashFolderPath:(NSString*)path;
- (void)setCountForNextSteps:(NSUInteger)count;

- (void)invalidateCountForPath:(NSString *)path;
- (void)invalidateUnseenCountForPath:(NSString *)path;

- (void)setCachedUnseenCount:(NSUInteger)count forPath:(NSString *)path;
- (void)setCachedCount:(NSUInteger)count forPath:(NSString *)path;

- (void)invalidateCountForStarred;
- (void)setCachedCountForStarred:(NSUInteger)count;

- (void)invalidateCountForNextSteps;
- (void)setCachedCountForNextSteps:(NSUInteger)count;

- (NSUInteger)cachedCountForPath:(NSString *)path;
- (NSUInteger)cachedUnseenCountForPath:(NSString *)path;
- (NSUInteger)cachedCountForStarredNotInTrashFolderPath:(NSString *)trashFolderPath;
- (NSUInteger)cachedCountForNextStepsNotInTrashFolderPath:(NSString*)trashFolderPath;

@end

@interface PSTDatabase (PSTConversationFetchOperations)

- (NSMutableArray *)conversationsForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder limit:(NSUInteger)limit;
- (NSMutableArray *)conversationsForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder allMailFolder:(BOOL)allMailFolder limit:(NSUInteger)limit;
- (NSMutableArray *)starredConversationsNotInTrashFolder:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit;
- (NSMutableArray *)nextStepsConversationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit;
- (NSMutableArray *)conversationsNotInTrashFolder:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit;
- (NSMutableArray *)unreadConversationsForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder limit:(NSUInteger)limit;

- (NSMutableArray *)facebookNotificationsNotInTrash:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit;
- (NSMutableArray *)twitterNotificationsNotInTrash:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit;

@end

@interface PSTDatabase (PSTConversationDetailsOperations)

- (PSTConversationCache *)rawConversationCacheForConversationID:(NSUInteger)convoID;
- (void)updateActionstepsForConversationID:(NSUInteger)conversationID actionStep:(PSTActionStepValue)actionStep;

- (NSArray *)localDraftMessagesForFolder:(MCOIMAPFolder *)folder;

- (NSArray *)messagesForConversationID:(NSUInteger)conversationID mainFolder:(MCOIMAPFolder *)folder folders:(NSDictionary *)foldersDictionary draftsFolderPath:(NSString *)draftsFolderPath sentMailFolderPath:(NSString *)sentMailFolderPath;
- (NSArray *)messagesForConversationID:(NSUInteger)conversationID folder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder draftsFolderPath:(NSString *)draftsFolderPath sentMailFolderPath:(NSString *)sentMailFolderPath;

- (NSArray *)duplicateMessagesForMessage:(MCOIMAPMessage *)message cache:(PSTConversationCache *)cache folders:(NSDictionary *)folders DEPRECATED_ATTRIBUTE;

@end

@interface PSTDatabase (PSTAttachmentOperations)

- (NSArray *)attachmentsInFolder:(MCOIMAPFolder *)folder;
- (NSArray *)attachmentsNotInTrashFolder:(MCOIMAPFolder *)trashFolder orAllMailFolder:(MCOIMAPFolder*)allMailFolder;
- (MCOIMAPMessagePart *)attachmentToFetchForFolder:(MCOIMAPFolder*)folder maxUID:(NSUInteger)maxUID fetchNonTextAttachents:(BOOL)fetchNonTextAttachments;

- (BOOL)hasDataForAttachmentMessage:(MCOAbstractMessage *)message atPath:(NSString *)path partID:(NSString *)partID filename:(NSString *)filename mimeType:(NSString *)mimeType;
- (NSData *)dataForAttachmentMessage:(MCOAbstractMessage *)message atPath:(NSString *)path partID:(NSString *)partID filename:(NSString *)filename mimeType:(NSString *)mimeType;

@end

@interface PSTDatabase (PSTSearchOperations)

- (BOOL)matchSearchStrings:(NSArray *)searchStrings withString:(NSString *)string;
- (NSArray *)searchConversationsWithTerms:(NSArray *)searchTerms kind:(NSInteger)kind folder:(NSString *)folder otherFolder:(NSString *)otherFolder mainFolders:(NSDictionary *)mainFolders mode:(NSInteger)mode limit:(NSInteger)limit returningEverything:(BOOL)returningEverything;

@end

@interface NSObject (PSTMessageDatabaseDelegate)

- (void)database:(PSTDatabase *)database didSetPath:(NSString *)path;
- (void)database:(PSTDatabase *)database didSetProgress:(float)progress;
- (void)database:(PSTDatabase *)database didSetProgressMax:(float)progressMax;

@end

extern PSTConversationCache *PSTConversationCacheForConversationID(NSUInteger cacheForConversationID, NSString *folderPath,
																   NSString *otherFolderPath, NSString *draftsFolderPath,
																   NSString *sentMailFolderPath, PSTDatabase *context);
extern NSString *PSTIdentifierForConversationCachePreview(PSTConversationCache *cache);
extern PSTConversationCache *PSTSearchConversationCacheForConversationID(NSUInteger cacheForConversationID, PSTDatabase *context);
