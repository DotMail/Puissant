//
//  PSTIncompleteMessageUIDsOperation.h
//  DotMail
//
//  Created by Robert Widmann on 10/23/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTStorageOperation.h"


@interface PSTIncompleteMessagesUIDOperation : PSTStorageOperation

- (void)start:(void(^)(NSIndexSet *messageUIDs))callback;

@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) NSUInteger limit;
@property (nonatomic, assign) NSUInteger lastUID;
@property (nonatomic, assign, readonly) NSUInteger count;

@end
