//
//  PSTRemoveMessageCacheOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTRemoveMessageCacheOperation : PSTStorageOperation

@property (nonatomic, assign) BOOL permanently;
@property (nonatomic, strong) NSNumber *messageID;
@property (nonatomic, strong) NSArray *paths;

@end
