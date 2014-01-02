//
//  PSTDatabaseController.h
//  DotMail
//
//  Created by Robert Widmann on 10/10/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

@class PSTDatabaseController;
@class PSTDatabase;
@class PSTIndexedMapTable;
@class PSTLevelDBMapTable;
@class PSTLevelDBCache;
@class PSTConversation;
@class PSTConversationCache;
@class PSTStorageOperation;
@class PSTActivity;
@class MCOIMAPFolder;
@class MCOIMAPMessage;
@class MCOAbstractMessage;
@class MCOAbstractPart;
@class RACSignal;

/**
 * Returns an initialized instance of PSTConversationCache using the parameters of the passed
 * conversation.  It is recommended that the conversation not be fully loaded before this method
 * is called so as to avoid unnecessary cache hits.
 */
PUISSANT_EXPORT PSTConversationCache *PSTConversationCacheForConversation(PSTConversation *conversation, PSTDatabaseController *context);

@interface PSTDatabaseController : NSObject

/**
 * Returns an PSTDatabaseController object initialized to correspond to the specified directory.
 */
- (id)initWithPath:(NSString *)path;

/**
 * Opens all databases at the specified path.  If necessary, new databases are created.
 */
- (RACSignal *)open;

/**
 * Closes and releases the databases associated with this controllers.
 */
- (void)close;

/**
 * Enqueues a PSTStorageOperation for execution on the main scheduler.  Operations that can be run
 * concurrently (i.e. those that do not reference the database), may be enqueued safely with this 
 * method.
 */
- (void)queueOperation:(PSTStorageOperation *)request;

/**
 * Enqueues a PSTStorageOperation for execution on the database scheduler.  Operations that can be 
 * run serially (i.e. those that reference the database), must be enqueued safely with this method.
 */
- (void)queueDatabaseOperation:(PSTStorageOperation *)request;

/**
 * Begin a series of method calls that modify conversations stored in the reciever.
 */
- (void)beginConversationUpdates;

/**
 * End a series of method calls that modify conversations stored in the reciever.
 */
- (void)endConversationUpdates;


/**
 * Forces a synchronous update to the folder identifiers portion of the database.
 */
- (void)updateFolderIdentifiersCache;

/**
 * 
 */
- (void)removeMessageCacheWithMessageID:(NSNumber *)msgID folderPath:(NSString *)path permanently:(BOOL)permanently;
- (void)removeMessageCacheWithMessageID:(NSNumber *)msgID toFolderPaths:(NSArray *)folderPaths permanently:(BOOL)permanently;

/**
 * Returns YES if the attachments database or the filesystem contains data for a given attachment, 
 * else no.
 */
- (BOOL)hasDataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path;

/**
 * Returns a valid instance of NSData if either the attachments databse or the filesystem contains
 * data for a given attachment, else nil.
 */
- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path;
- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment onMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

/**
 * Returns YES if the messages database contains message data and a body for the given message, else
 * NO.
 */
- (BOOL)hasDataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path;

/**
 * Returns a valid instance of NSData if the message database contains message data and a body for
 * the given message, else nil.
 */
- (NSData *)dataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path;

/**
 * Returns YES if the preview database contains data for the given message, else NO.
 */
- (BOOL)hasPreviewForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path;

/**
 * Returns a valid preview string if the message database contains the preview data for the given
 * message, else nil;
 */
- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

/**
 * Returns YES if the message database or it's folder cache have already serialized the given folder
 * path.
 */
- (BOOL)containsFolderPath:(NSString *)path;

/**
 * Returns the number of operations currently in all queues managed by the reciever.
 */
- (NSUInteger)operationCount;

/**
 * Blocks the current thread until all of the receiver’s queued and executing operations finish 
 * executing.
 */
- (void)waitUntilAllOperationsHaveFinished;

/**
 * Cancels all queued and executing operations.
 */
- (void)cancelAllOperations;

- (NSUInteger)cachedCountForFolder:(MCOIMAPFolder *)folder;
- (NSUInteger)cachedUnseenCountForFolder:(MCOIMAPFolder *)folder;
- (NSUInteger)cachedCountForStarredNotInTrashFolder:(MCOIMAPFolder *)folder;
- (NSUInteger)cachedCountForNextStepsNotInTrashFolderPath:(MCOIMAPFolder *)folder;

@property (nonatomic, copy, readonly) NSString *path;

@property (nonatomic, copy) NSString *localDraftsPath;
@property (nonatomic, copy) NSString *email;

@property (nonatomic, strong) PSTDatabase *databaseConnection;
@property (nonatomic, strong) PSTDatabase *countDatabaseConnection;

@end

/// Sent when the database has successfully opened all of it's sub-caches.
PUISSANT_EXPORT NSString *const PSTStorageReadyNotification;

