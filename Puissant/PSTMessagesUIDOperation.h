//
//  PSTMessagesUIDOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTMessagesUIDOperation : PSTStorageOperation

@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSIndexSet *uidsSet;

@end
