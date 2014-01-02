//
//  PSTRemoveLocalMessagesOperation.h
//  Puissant
//
//  Created by Robert Widmann on 1/27/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTRemoveLocalMessagesOperation : PSTStorageOperation

@property (nonatomic, copy) NSString *path;

@end
