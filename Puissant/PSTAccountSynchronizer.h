//
//  PSTAbstractSynchronizer.h
//  DotMail
//
//  Created by Robert Widmann on 10/20/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <MailCore/MCOConstants.h>

@class PSTDatabaseController;
@class MCOIMAPFolder;
@class RACSignal;

@interface PSTAccountSynchronizer : NSObject

@property (nonatomic, strong) PSTDatabaseController *databaseController;
@property (nonatomic, assign) BOOL syncing;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger errorCount;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) int port;
@property (nonatomic, assign) unichar namespaceDelimiter;
@property (nonatomic, assign) MCOConnectionType connectionType;
@property (nonatomic, copy) NSString *providerIdentifier;
@property (nonatomic, copy) NSString *namespacePrefix;
@property (nonatomic, strong) NSDictionary *xListMapping;
@property (nonatomic, assign) NSUInteger inboxRefreshDelay;
@property (nonatomic, strong) MCOIMAPFolder *selectedFolder;
@property (nonatomic, strong) NSMutableArray *currentConversations;
@property (nonatomic, strong) NSMutableArray *currentSearchResult;

@property (nonatomic, assign, getter = isSelectedStarred) BOOL selectedStarred;
@property (nonatomic, assign, getter = isSelectedUnread) BOOL selectedUnread;
@property (nonatomic, assign, getter = isSelectedNextSteps) BOOL selectedNextSteps;
@property (nonatomic, assign) BOOL localDraftsSyncDisabled;

- (RACSignal *)sync;
- (void)cancel;

- (NSUInteger)countForFolder:(MCOIMAPFolder *)folder;
- (NSUInteger)unseenCountForFolder:(MCOIMAPFolder *)folder;
- (NSUInteger)countForStarred;
- (NSUInteger)countForNextSteps;

- (BOOL)isSelectedFolderAvailable:(MCOIMAPFolder *)folder;

- (void)refreshSyncForFolder:(MCOIMAPFolder *)folder;
- (void)createFolder:(NSString *)folderPath;
- (void)deleteFolder:(NSString *)folderPath;
- (void)renameFolder:(MCOIMAPFolder *)folderToRename newName:(NSString *)newName;

@end
