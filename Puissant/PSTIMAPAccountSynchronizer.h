//
//  PSTAccountSynchronizer.h
//  DotMail
//
//  Created by Robert Widmann on 10/11/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/mailcore.h>
#import "PSTAccountSynchronizer.h"

@class PSTIMAPFolderSynchronizer;
@class PSTMailAccount;
@class PSTConversation;
@class RACSignal;

@protocol PSTIMAPAccountSynchronizerDelegate;

/*
 * A concrete mediator class that is meant to be the real heavy lifting behind a
 * PSTMailAccount's properties.  This class is responsible for the fetching of folders,
 * and then instantiating PSTIMAPFolderSynchronizer objects to fetch the messages from them.
 * Delegate methods will be sent along the way, and activity objects will be created regularly.
 *
 * This class is instantiated by it's owning PSTMailAccount, do not make one yourself.
 */
@interface PSTIMAPAccountSynchronizer : PSTAccountSynchronizer

/**
 * Returns a valid PSTIMAPAccountSynchronizer object.  This is the standard initializer for the class.
 */
- (id)init;

- (void)addMessagesToDelete:(NSArray *)messages;
- (void)removeConversation:(PSTConversation *)conversation;

//Spawns a new sychronization series and refreshes all folders.
- (RACSignal *)refreshSync;

//Adds the given folders to the internal folders set.
- (void)addFoldersWithPaths:(NSArray*)folderPaths;

- (MCOIMAPFolder *)folderForPath:(NSString*)path;

- (NSDictionary *)folderMappingWithoutTrash;

- (void)checkNotifications;

- (void)beginConversationUpdates;
- (void)endConversationUpdates;
- (void)addModifiedMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

//Cancels the currently occuring synchronization series
- (void)invalidateSynchronizer;
- (void)waitUntilAllOperationsHaveFinished;
- (void)searchWithTerms:(NSArray *)terms complete:(BOOL)complete searchStringToComplete:(NSAttributedString *)attributedString;
- (NSArray *)searchSuggestions;
- (void)cancelSearch;
- (void)cancelRemoteSearch;

@property (nonatomic, strong, readonly) MCOIMAPSession *session;
@property (nonatomic, assign) id<PSTIMAPAccountSynchronizerDelegate> delegate;
@property (nonatomic, strong, readonly) NSMutableArray *folders;
@property (nonatomic, strong, readonly) NSMutableArray *nonSelectableFolders;
@property (nonatomic, assign) PSTFolderType selected;
@property (nonatomic, assign) NSUInteger requestBySequenceCount;

@end

@interface PSTIMAPAccountSynchronizer (PSTFolderGetters)

@property (nonatomic, strong, readonly) MCOIMAPFolder *inboxFolder;
@property (nonatomic, strong, readonly) MCOIMAPFolder *trashFolder;
@property (nonatomic, strong, readonly) MCOIMAPFolder *sentMailFolder;
@property (nonatomic, strong, readonly) MCOIMAPFolder *allMailFolder;
@property (nonatomic, strong, readonly) MCOIMAPFolder *starredFolder;
@property (nonatomic, strong, readonly) MCOIMAPFolder *draftsFolder;
@property (nonatomic, strong, readonly) MCOIMAPFolder *importantFolder;
@property (nonatomic, strong, readonly) MCOIMAPFolder *spamFolder;

@end

@interface PSTIMAPAccountSynchronizer (PSTPersisentDataAccess)

- (BOOL)hasDataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path;
- (BOOL)hasDataForAttachment:(MCOAbstractPart *)message atPath:(NSString *)path;
- (NSData *)dataForMessage:(MCOIMAPMessage *)attachment atPath:(NSString *)path;
- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path;
- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment onMessage:(MCOIMAPMessage *)message atPath:(NSString *)path;
- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path;

@end

@interface PSTIMAPAccountSynchronizer (PSTSaving)

- (RACSignal *)saveState;
- (RACSignal *)saveMessage:(id)message;

@end

@interface PSTIMAPAccountSynchronizer (PSTSocialSignals)

- (RACSignal *)twitterMessagesSignal;
- (RACSignal *)facebookMessagesSignal;
- (RACSignal *)attachmentsSignal;

@end

@protocol PSTIMAPAccountSynchronizerDelegate <NSObject>
- (void)accountSynchronizerDidSetupAccount:(PSTIMAPAccountSynchronizer *)synchronizer;
- (void)accountSynchronizerWillUpdateFolders:(PSTIMAPAccountSynchronizer *)synchronizer;
- (void)accountSynchronizerDidUpdateFolders:(PSTIMAPAccountSynchronizer *)synchronizer;
- (void)accountSynchronizerDidUpdateLabels:(PSTIMAPAccountSynchronizer *)synchronizer;
- (void)accountSynchronizerFetchedFolders:(PSTIMAPAccountSynchronizer *)synchronizer;
- (void)accountSynchronizerDidUpdateXListMapping:(PSTIMAPAccountSynchronizer *)synchronizer;
- (void)accountSynchronizerDidUpdateNamespace:(PSTIMAPAccountSynchronizer *)synchronizer;
- (void)accountSynchronizerDidUpdateCount:(PSTIMAPAccountSynchronizer *)synchronizer;
- (void)accountSynchronizerDidUpdateSearchResults:(PSTIMAPAccountSynchronizer *)synchronizer;
- (void)accountSynchronizer:(PSTIMAPAccountSynchronizer* )synchronizer postNotificationForMessages:(NSArray*)messages conversationIDs:(NSArray*)conversationIDs;
- (void)accountSynchronizerNeedsRefresh:(PSTIMAPAccountSynchronizer *)synchronizer;
@end
