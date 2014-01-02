//
//  PSTMessageIndex.h
//  Puissant
//
//  Created by Robert Widmann on 11/13/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMDatabase;

@interface PSTMessageIndex : NSObject

@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) FMDatabase *database;
@property (nonatomic, assign) id delegate;

- (BOOL)openAndCheckConsistency;
- (void)close;

- (NSArray *)conversationsForSearchedTerms:(NSArray *)searchTerms searchKind:(NSInteger)searchKind mainFolders:(NSDictionary *)mainFolders allFoldersIDs:(NSDictionary *)folderIDs mode:(NSInteger)mode limit:(NSUInteger)limit returnedEverything:(BOOL)returningEverything;


@end
