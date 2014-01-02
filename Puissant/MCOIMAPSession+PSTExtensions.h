//
//  MCOIMAPSession+PSTExtensions.h
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <MailCore/MCOIMAPSession.h>

@class MCOIMAPFolder, MCOMailProvider;


@interface MCOIMAPSession (PSTExtensions)

+ (NSDictionary *)XListMappingWithFolders:(NSArray * /* MCOIMAPFolder */ )folders;

- (MCOIMAPFolder *)sentMailFolderForProvider:(MCOMailProvider *)provider;
- (MCOIMAPFolder *)starredFolderForProvider:(MCOMailProvider *)provider;
- (MCOIMAPFolder *)allMailFolderForProvider:(MCOMailProvider *)provider;
- (MCOIMAPFolder *)trashFolderForProvider:(MCOMailProvider *)provider;
- (MCOIMAPFolder *)draftsFolderForProvider:(MCOMailProvider *)provider;
- (MCOIMAPFolder *)spamFolderForProvider:(MCOMailProvider *)provider;
- (MCOIMAPFolder *)importantFolderForProvider:(MCOMailProvider *)provider;

- (void)setupNamespaceWithPrefix:(NSString *)prefix delimiter:(char)delimiter;
- (MCOIMAPFolder *)inboxFolder;

- (MCOIMAPFolder *)folderWithPath:(NSString *)path;

@property (nonatomic, strong) NSDictionary *dm_XListMapping;

@end
