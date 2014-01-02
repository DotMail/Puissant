//
//  PSTCommitFlagsOperation.h
//  Puissant
//
//  Created by Robert Widmann on 4/2/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPFolder;

@interface PSTCommitFlagsOperation : PSTStorageOperation

@property (nonatomic, strong) NSArray *modifiedMessages;
@property (nonatomic, strong) MCOIMAPFolder *folder;

@end
