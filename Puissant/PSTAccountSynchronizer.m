//
//  PSTAbstractSynchronizer.m
//  DotMail
//
//  Created by Robert Widmann on 10/20/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTAccountSynchronizer.h"

@implementation PSTAccountSynchronizer

- (NSDictionary*)foldersDictionaryExceptTrash:(BOOL)exceptTrash {
	return nil;
}

- (RACSignal *)sync { return [RACSignal empty]; }
- (void)cancel {}

- (void)createFolder:(NSString*)folderPath {}
- (void)deleteFolder:(NSString*)folderPath {}
- (void)renameFolder:(MCOIMAPFolder*)folderToRename newName:(NSString*)newName {}

- (NSUInteger)countForFolder:(MCOIMAPFolder*)folder {
	return 0;
}

- (NSUInteger)unseenCountForFolder:(MCOIMAPFolder*)folder {
	return 0;
}

- (NSUInteger)countForStarred {
	return 0;
}

- (NSUInteger)countForNextSteps {
	return 0;
}

- (BOOL)isSelectedFolderAvailable:(MCOIMAPFolder*)folder {
	return NO;
}

- (void)refreshSyncForFolder:(MCOIMAPFolder*)folder {}

@end
