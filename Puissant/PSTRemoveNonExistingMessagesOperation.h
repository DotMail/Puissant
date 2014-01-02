//
//  PSTRemoveNonExistingMessagesOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTRemoveNonExistingMessagesOperation : PSTStorageOperation

@property (nonatomic, assign) BOOL hasNonExisting;
@property (nonatomic, assign) BOOL hasResurrect;

@property (nonatomic, assign) NSUInteger deletedMessageCount;

@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSIndexSet *uidsSet;

@end
