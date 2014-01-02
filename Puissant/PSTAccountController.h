//
//  CFIUnifiedAccount.h
//  DotMail
//
//  Created by Robert Widmann on 8/5/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSTMailAccount;
@class PSTConversation;
@class MCOAddress;
@class MCOAbstractMessage;

/*!
 * A class that manages a PSTAccount object, and provides the gateway to 
 * accessing it's properties from outside of the class itself.  The object comes
 * in two flavors: Truly unified, or Singleton.  Truly unified managers contain 
 * multiple accounts, and are used to synchronize them all and interpret 
 * requests for their properties.  Not-Truly Unified accounts contain one 
 * account, and only synchronize that account.
 */
@interface PSTAccountController : NSObject

/*!
 * Returns an initialized Account Controller object representing the current
 * account.  This is the default initializer for the class.
 */
- (id)initWithAccount:(PSTMailAccount *)account;

/*
 * Returns an initialized Account Controller that owns an array of accounts.
 */
- (id)initWithAccounts:(NSArray *)accounts;

/*!
 * Returns an array of PSTMailAccount objects representing the accounts that this
 * controller owns.
 * Note: This is set automatically by the default initializer for the class.
 * For all other initializers, this is either empty or nil.
 */
@property (nonatomic, strong, readonly) NSArray *accounts;

/*!
 * A unique identifier for this account controller for uniquing purposes.
 */
@property (nonatomic, copy, readonly) NSString *identifier;

/*!
 * Represents the currently selected folder for the given account.
 */
@property (nonatomic, assign) PSTFolderType selectedFolder;

/*!
 * The folder path of the currently selected label, or nil if none is selected.
 */
@property (nonatomic, copy) NSString *selectedLabel;

/*!
 * An array of PSTConversation objects that represents the combined conversations
 * from each of the controller's accounts.
 * Note: This property should never be nil and is KVO-compliant.
 */
@property (nonatomic, strong, readonly) NSArray *currentConversations;

/*!
 * An array of PSTConversation objects that represents the combined search
 * results from each of the controller's accounts.  
 * Note: This property should never be nil and is KVO-compliant.
 */
@property (nonatomic, strong, readonly) NSArray *currentSearchResult;

/*!
 * Returns the first account registered with DotMail or nil if no accounts
 * exist.
 */
@property (nonatomic, strong, readonly) PSTMailAccount *mainAccount;

/*!
 * Returns the email associated with either the first account of this account
 * controller or nil if no accounts have been setup.
 */
@property (nonatomic, copy, readonly) NSString *email;

/*!
 * An array of the labels that should be shown when this account has been
 * selected or an empty array if this account controller manages multiple
 * accounts.
 */
@property (nonatomic, strong, readonly) NSArray *visibleLabels;


@property (nonatomic, assign) BOOL loading;

/*!
 * Returns whether this Unified Account contains more than one PSTMailAccount
 * object.
 */
- (BOOL)hasMultipleAccounts;

/*!
 * Returns whether a given folder can be selected.  Returns yes if the folder is
 * valid and can be synchronized.
 */
- (BOOL)isFolderSelectionAvailable:(PSTFolderType)selection;

/*!
 * Returns the cached count of all emails for all accounts.
 */
- (NSUInteger)countForFolder:(PSTFolderType)folder;

/*!
 * Returns the cached count of all unread emails for all accounts.
 */
- (NSUInteger)unreadCountForFolder:(PSTFolderType)folder;

/*!
 * Runs a refresh synchronization series on all accounts.
 */
- (void)refreshSync;

/*!
 * A convenience method to force all accounts to set their selected folders to 
 * the inbox folder.
 */
- (void)selectInbox;

- (void)searchWithTerms:(NSArray *)terms complete:(BOOL)complete searchStringToComplete:(NSAttributedString *)attributedString;
- (NSDictionary *)searchSuggestionsTerms;
- (void)cancelSearch;

- (void)deleteConversation:(PSTConversation *)conversation;

- (NSData *)dataForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;
- (BOOL)hasDataForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

- (MCOAddress *)addressValueWithName:(BOOL)name;

@end

@interface PSTAccountController (PSTSocialSignals)

- (RACSignal *)attachmentsSignal;
- (RACSignal *)facebookMessagesSignal;
- (RACSignal *)twitterMessagesSignal;

@end
