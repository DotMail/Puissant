//
//  PSTMailAccount.h
//  DotMail
//
//  Created by Robert Widmann on 9/8/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTAccountSynchronizer.h"

PUISSANT_EXPORT NSString *const PSTDraftsFolderPathKey;
PUISSANT_EXPORT NSString *const PSTSentMailFolderPathKey;
PUISSANT_EXPORT NSString *const PSTImportantFolderPathKey;
PUISSANT_EXPORT NSString *const PSTSpamFolderPathKey;

@class MCOAddress;
@class MCOIMAPMessage;
@class MCOAbstractMessage;
@class PSTConversation;

/**
 * A class that represents an email account (either POP or IMAP).  The class is
 * responsible for the instantiation and execution of PSTAccountSynchronizers,
 * and chooses the right ones to instantiate so long as the correct properties
 * are provided.  The class is meant to be saved to a dictionary so it can be
 * retrieved later.  Use -initWithDictionary: and -info to set and get this
 * dictionary respectively.
 */
@interface PSTMailAccount : NSObject

/// Convenience for the HTML signature that the account defaults to at creation.
+ (NSString *)defaultHTMLSignatureSuffix;

/**
 * Returns an initialized Account object with the given dictionary.  This should
 * only be used in conjunction with an account being loaded from NSUserDefaults.
 */
- (id)initWithDictionary:(NSDictionary *)dictionary;

/**
 * Returns the account's properties serialized into an NSDictionary so as to
 * permit archiving.  Note: The class does not serialize the -password property,
 * as that should be stored in the keychain.
 */
- (NSDictionary *)dictionaryValue;

/**
 * The display name of this account.
 */
@property (nonatomic, copy, readonly) NSString *name;

/**
 * The email address of this account.
 */
@property (nonatomic, copy, readonly) NSString *email;

/**
 * Returns a dictionary of folders (object: MCOIMAPFolder key:folder.path)except
 * the trash folder.
 * Note: This is particularly helpful for conversations involving folders that 
 * cannot be sync'd (such as the starred folder), as those must exclude trashed
 * messages).
 */
@property (nonatomic, strong, readonly) NSDictionary *folders;

/*!
 * An array of PSTConversation objects that represents the conversations from
 * this account.
 * Note: This property should never be nil and is KVO-compliant.
 */
@property (nonatomic, strong, readonly) NSArray *currentConversations;

/*!
 * An array of PSTConversation objects that represents the search results from
 * this account.
 * Note: This property should never be nil and is KVO-compliant.
 */
@property (nonatomic, strong, readonly) NSArray *currentSearchResult;

/**
 * Runs the initial synchronization series on this account.
 * Note: This methods should only be called once; just after the creation of an
 * Account object.  To run a sync after that, use -refreshSync.
 */
- (void)sync;

/**
 * Runs a refresh sync series on all folders and labels.
 */
- (void)refreshSync;

/**
 * 
 */
- (void)checkNotifications;



/**
 * Sends a given MailCore message.
 */
- (void)sendMessage:(id)message completion:(void(^)())completion;

/**
 * Writes a given MailCore message to disk.
 */
- (void)saveMessage:(id)message completion:(void(^)())completion;



/**
 * Returns the account's email as a MCOAddress or nil if one cannot be created.
 */
- (MCOAddress *)addressValueWithName:(BOOL)name;


/**
 * Flushes sync dates to a plist and halts the account's synchronizer.
 */
- (void)save;

/**
 * Permanently removes all files and state associated with a given account and stops all pending
 * operations running against that account.
 */
- (void)remove;


- (void)deleteConversation:(PSTConversation *)conversation;

@property (nonatomic, copy) NSString *htmlSignature;
@property (nonatomic, copy) NSString *selectedLabel;
@property (nonatomic, assign) PSTFolderType selected;
@property (nonatomic, assign) BOOL notificationsEnabled;
@property (nonatomic, assign) BOOL loading;

@end

@interface PSTMailAccount (PSTXLIST)

/**
 * Returns an array of all labels appropriate for showing to the
 * user or that the user has explicitly enabled.
 */
- (NSArray *)visibleLabels;

/**
 * Returns an array of all labels.
 */
- (NSArray *)allLabels;



/**
 * Sets a given color for a label or string identifier.
 */
- (void)setColor:(NSColor *)color forLabel:(NSString *)label;

/**
 * Returns the color for a given label or string identifier.
 */
- (NSColor *)colorForLabel:(NSString *)label;


@end

@interface PSTMailAccount (PSTPersisentDataAccess)

/**
 * Queries the database to check whether the body of this message has been fetched and saved.
 * Returns yes if the database contains an NSData object for the given message.
 */
- (BOOL)hasDataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path;

/**
 * Queries the database for the body data associated with the given message.  Returns data if it
 * exists, or nil.
 */
- (NSData *)dataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path;

/**
 * Queries the database to check whether the data for this attachment has been fetched and saved.
 * Returns yes if the database contains an NSData object for the given message.
 */
- (BOOL)hasDataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path;

/**
 * Queries the database for the data associated with the given attachment.  Returns data if it
 * exists, or nil.
 */
- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path;

- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment onMessage:(MCOIMAPMessage *)message atPath:(NSString *)path;

/**
 * Queries the database for the preview data associated with the given message.  Returns a valid
 * string if the database has preview data, else nil.
 */
- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

/**
 * Returns whether the given selection exists, and can be synchronized.  Returns yes if the given
 * folder can be selected, else no.
 */
- (BOOL)isSelectionAvailable:(PSTFolderType)selection;

/**
 * Returns the cached count of all messages for the given folder;
 */
- (NSUInteger)countForFolder:(PSTFolderType)folder;

/**
 * Returns the cached count of all undread messages for the given folder;
 */
- (NSUInteger)unreadCountForFolder:(PSTFolderType)folder;

/**
 * Tells the account's synchronizer to wait until all operations have finished.
 */
- (void)waitUntilAllOperationsHaveFinished;

/**
 * Tells the database to prepare for an update to conversations.  Internally, this increments a lock
 * on the database, and the synchronizer so they can update appropriately.
 */
- (void)beginConversationUpdates;

/**
 * Adds the message to a modified message queue.  Should only be called in
 * between a call to [begin/end]ConversationUpdates.
 */
- (void)addModifiedMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

/**
 * Tells the database to prepare for an update to conversations.  Internally, this decrements a lock
 * on the database, and the synchronizer so they can update appropriately.
 */
- (void)endConversationUpdates;

@end

@interface PSTMailAccount (PSTSearch)

- (void)searchWithTerms:(NSArray *)terms complete:(BOOL)complete searchStringToComplete:(NSAttributedString *)attributedString;
- (void)cancelSearch;
- (NSArray *)searchSuggestions;

@end

@interface PSTMailAccount (PSTSocialSignals)

- (RACSignal *)facebookMessagesSignal;
- (RACSignal *)attachmentsSignal;
- (RACSignal *)twitterMessagesSignal;

@end

PUISSANT_EXPORT NSString *const PSTMailAccountNotificationChanged;
PUISSANT_EXPORT NSString *const PSTMailAccountCountUpdated;
PUISSANT_EXPORT NSString *const PSTMailAccountActionStepCountUpdated;
PUISSANT_EXPORT NSString *const PSTMailAccountLabelsColorsChanged;
PUISSANT_EXPORT NSString *const PSTMailAccountSynchronizerModifiedConversations;
PUISSANT_EXPORT NSString *const PSTMailAccountMessageDidSendMessageNotification;
PUISSANT_EXPORT NSString *const PSTMailAccountConversationForMessageIDFetched;

PUISSANT_EXPORT NSString *const PSTMailAccountLabelOperationSucceeded;

