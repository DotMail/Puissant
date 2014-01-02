//
//  PSTLocalDraftMessagesOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/28/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTLocalDraftMessagesOperation.h"
#import "PSTDatabase.h"

@implementation PSTLocalDraftMessagesOperation

- (id)init {
	if (self = [super init]) {
		
	}
	return self;
}

- (void)mainRequest {
	[self.database beginTransaction];
	self.messages = [self.database localDraftMessagesForFolder:self.folder];
	[self.database commit];
}

@end
