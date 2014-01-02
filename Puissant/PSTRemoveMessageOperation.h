//
//  PSTRemoveMessageOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/1/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPMessage;

@interface PSTRemoveMessageOperation : PSTStorageOperation

@property (nonatomic, strong) MCOIMAPMessage *message;

@end
