//
//  PSTMarkMessagesAsDeletedOperation.m
//  Puissant
//
//  Created by Robert Widmann on 7/7/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTMarkMessagesAsDeletedOperation.h"
#import "PSTDatabase.h"
#import "PSTCachedMessage.h"

@implementation PSTMarkMessagesAsDeletedOperation{
	void(^_callback)(void);
}

- (void)start:(void(^)(void))callback {
	_callback = callback;
	[super startRequest];
}


- (void)mainRequest {
	if (self.messages.count) {
		[self.database beginTransaction];
		for (PSTSerializableMessage *message in self.messages) {
			[self.database markMessageAsDeleted:message];
		}
		[self.database commit];
	}
}

- (void)mainFinished {
	if (_callback) {
		_callback();
	}
}

@end
