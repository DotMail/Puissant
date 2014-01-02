//
//  PSTUpdateMessagesFlagsFromUserOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTUpdateMessagesFlagsFromUserOperation : PSTStorageOperation

@property (nonatomic, strong) NSDictionary *messageMap;
- (void)start:(void(^)(void))callback;

@end
