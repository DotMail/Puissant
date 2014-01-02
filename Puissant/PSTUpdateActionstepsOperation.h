//
//  PSTUpdateActionstepsOperation.h
//  Puissant
//
//  Created by Robert Widmann on 2/8/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@interface PSTUpdateActionstepsOperation : PSTStorageOperation

@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) NSUInteger conversationID;
@property (nonatomic, assign) PSTActionStepValue actionStep;

@end
