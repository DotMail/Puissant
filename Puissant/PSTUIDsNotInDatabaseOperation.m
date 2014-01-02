//
//  PSTUIDsNotInDatabaseOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTUIDsNotInDatabaseOperation.h"
#import "PSTDatabase.h"

@implementation PSTUIDsNotInDatabaseOperation {
	NSIndexSet *_filteredUIDs;
	void(^_callback)(NSIndexSet *);
}

- (void)start:(void(^)(NSIndexSet *))callback {
	_callback = callback;
	[super startRequest];
}


- (void)mainRequest {
	_filteredUIDs = [self.database messagesUIDsNotInDatabase:self.messages forPath:self.path];
}

- (void)mainFinished {
	if (_callback) {
		_callback(_filteredUIDs);
	}
}

@end
