//
//  PSTMarkMessagesAsDeletedOperation.h
//  Puissant
//
//  Created by Robert Widmann on 7/7/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTMarkMessagesAsDeletedOperation : PSTStorageOperation

- (void)start:(void(^)(void))callback;

@property (nonatomic, strong) NSArray *pathsToCommit;
@property (nonatomic, strong) NSArray *messages;


@end
