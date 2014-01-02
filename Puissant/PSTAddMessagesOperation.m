//
//  PSTAddMessagesOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/21/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTAddMessagesOperation.h"
#import "PSTDatabase.h"
#import <MailCore/mailcore.h>

@interface PSTAddMessagesOperation ()

@end

@implementation PSTAddMessagesOperation {
	void(^_callback)(void);
}

- (void)start:(void(^)(void))callback {
	_callback = callback;
	[super startRequest];
}

- (void)mainRequest {
	NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
	[self.database beginTransaction];
	int successes = 0;
	for (MCOIMAPMessage *message in self.messages) {
		if (self.isCancelled) break;
		@autoreleasepool {
			BOOL result = [self.database addMessage:message inFolder:self.path];
			if (result) {
				[self.database cacheOriginalFlagsFromMessage:message inFolder:self.path];
				[self.database cacheFlagsFromMessage:message inFolder:self.path];
				[dict setObject:message forKey:[NSString stringWithFormat:@"%u", message.uid]];
				successes++;
			}
		}
	}
	[self.database commit];
	if (successes != 0) {
		[self.database appendCachedMessageFlags:dict forPath:self.path];
	}
	[self.database commitMessageUIDs];
}

- (void)mainFinished {
	if (_callback) {
		_callback();
	}
}

@end
