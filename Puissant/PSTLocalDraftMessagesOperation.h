//
//  PSTLocalDraftMessagesOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/28/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPFolder;

@interface PSTLocalDraftMessagesOperation : PSTStorageOperation

@property (nonatomic, strong) MCOIMAPFolder *folder;
@property (nonatomic, copy) NSArray *messages;

@end
