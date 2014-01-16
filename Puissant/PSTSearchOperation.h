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

@property (nonatomic, copy) NSString *query;

@end
