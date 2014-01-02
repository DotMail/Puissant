//
//  PSTMessagesUIDOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTMessagesUIDOperation.h"
#import "PSTDatabase.h"

@implementation PSTMessagesUIDOperation

- (void)mainRequest {
	self.uidsSet = [self.database messagesUIDsSetForPath:self.path];
}

@end
