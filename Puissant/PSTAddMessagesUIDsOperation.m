//
//  PSTAddMessagesUIDsOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/21/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTAddMessagesUIDsOperation.h"
#import "PSTDatabase.h"
#import <MailCore/mailcore.h>

@interface PSTAddMessagesUIDsOperation ()

@property (nonatomic, assign) NSUInteger lastUID;

@end

@implementation PSTAddMessagesUIDsOperation {
	void(^_callback)(void);
}

- (void)start:(void(^)(void))callback {
	_callback = callback;
	[super startRequest];
}

- (void)mainRequest {
	if (self.messages.count != 0) {
		[self.database beginTransaction];
		if (self.folder) {
			[self.messages enumerateIndexesUsingBlock:^(NSUInteger uid, BOOL *stop) {
				[self.database addMessageUID:uid forPath:self.folder.path];
			}];
		} else {

		}
		[self.database commit];
		[self.database commitMessageUIDs];
	}
}

- (void)mainFinished {
	if (_callback) {
		_callback();
	}
}

@end
