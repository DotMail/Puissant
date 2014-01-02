//
//  PSTUpdateMessagesFlagsFromServerOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTUpdateMessagesFlagsFromServerOperation : PSTStorageOperation

@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, assign) BOOL hasDeletedFlags;
@property (nonatomic, assign) BOOL hadChanges;
@property (nonatomic, copy) NSString *path;

@end
