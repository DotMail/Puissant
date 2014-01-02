//
//  PSTLoadCachedFlagsOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTLoadCachedFlagsOperation : PSTStorageOperation

@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSMutableArray *messagesFlags;
@property (nonatomic, assign) BOOL importMode;

@end
