//
//  PSTIncompleteMessagesUIDOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/21/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTIncompleteMessagesUIDOperation.h"
#import "PSTDatabase.h"

@interface PSTIncompleteMessagesUIDOperation ()

@property (nonatomic, assign) NSUInteger count;

@end

@implementation PSTIncompleteMessagesUIDOperation {
	void(^_callback)(NSIndexSet *messageUIDs);
	NSIndexSet *messageUIDs;
}

- (void)start:(void(^)(NSIndexSet *messageUIDs))callback {
	_callback = callback;
	[super startRequest];
}

- (void)mainRequest {
	NSUInteger newLastIncomplete = [self.database firstIncompleteUIDToFetch:self.path givenLastUID:self.lastUID];
	self.count = [self.database countOfIncompleteMessagesForFolderPath:self.path];
	messageUIDs = [self.database incompleteMessagesSetForFolderPath:self.path lastUID:newLastIncomplete limit:self.limit];
}

- (void)mainFinished {
	if (_callback) {
		_callback(messageUIDs);
	}
}

@end
