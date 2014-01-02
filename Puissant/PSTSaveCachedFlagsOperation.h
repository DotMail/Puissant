//
//  PSTSaveCachedFlagsOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTSaveCachedFlagsOperation : PSTStorageOperation

@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSDictionary *messagesDict;
@property (nonatomic, copy) NSString *path;

@end
