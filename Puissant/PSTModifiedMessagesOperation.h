//
//  PSTModifiedMessagesOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/3/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPFolder;

@interface PSTModifiedMessagesOperation : PSTStorageOperation

- (void)start:(void(^)(NSMutableArray *mDelete, NSMutableArray *mPurge, NSMutableArray *mModify, NSMutableArray *mCopy))callback;

@property (nonatomic, strong) MCOIMAPFolder *folder;


@end
