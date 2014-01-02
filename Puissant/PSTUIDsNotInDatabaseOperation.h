//
//  PSTUIDsNotInDatabaseOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTUIDsNotInDatabaseOperation : PSTStorageOperation

- (void)start:(void(^)(NSIndexSet *))callback;

@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSArray *messages;

@end
