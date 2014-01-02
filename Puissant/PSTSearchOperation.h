//
//  PSTSearchOperation.h
//  Puissant
//
//  Created by Robert Widmann on 7/5/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPFolder;

@interface PSTSearchOperation : PSTStorageOperation

- (void)start:(void(^)(BOOL, NSMutableSet *, NSMutableSet *, NSMutableSet *))callback;

@property (nonatomic, copy) NSArray *searchTerms;
@property (nonatomic) NSInteger kind;
@property (nonatomic, copy) MCOIMAPFolder *folder;
@property (nonatomic, copy) MCOIMAPFolder *otherFolder;
@property (nonatomic) NSInteger mode;
@property (nonatomic) NSInteger limit;
@property (nonatomic, strong) NSDictionary *mainFolders;
@property (nonatomic) BOOL returnedEverything;

@property (nonatomic, copy) NSAttributedString *searchStringToComplete;
@property (nonatomic, strong) NSArray *conversations;

@property (nonatomic) BOOL needsSuggestions;
@end
