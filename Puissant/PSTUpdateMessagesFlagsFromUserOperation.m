//
//  PSTUpdateMessagesFlagsFromUserOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTUpdateMessagesFlagsFromUserOperation.h"
#import "PSTDatabase.h"

@implementation PSTUpdateMessagesFlagsFromUserOperation {
	void(^_callback)(void);
}

- (void)start:(void(^)(void))callback {
	_callback = callback;
	[super startRequest];
}

- (void)mainRequest {
	[self.database beginTransaction];
	@autoreleasepool {
		for (NSString *folderPath in self.messageMap.allKeys) {
			for (MCOIMAPMessage *message in self.messageMap[folderPath]) {
				[self.database updateMessageFlagsFromUser:(MCOAbstractMessage *)message forFolder:folderPath];
			}
		}
	}
	[self.database commit];
}

- (void)mainFinished {
	if (_callback) {
		_callback();
	}
}

@end
