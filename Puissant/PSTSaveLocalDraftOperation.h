//
//  PSTSaveLocalDraftOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/10/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPMessage;

@interface PSTSaveLocalDraftOperation : PSTStorageOperation

@property (nonatomic, strong) MCOIMAPMessage *originalMessage;

@end
