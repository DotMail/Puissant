//
//  PSTUpdateMessagesFlagsFromServerOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTUpdateMessagesFlagsFromServerOperation.h"
#import "PSTDatabase.h"
#import <MailCore/mailcore.h>

@implementation PSTUpdateMessagesFlagsFromServerOperation

- (void)mainRequest {
	[self.database beginTransaction];
	for (MCOIMAPMessage *message in self.messages) {
		if ([self.database areFlagsChangedOnMessage:message forPath:self.path]) {
			@autoreleasepool {
				BOOL flagsUpdated = [self.database updateMessageFlagsFromServer:message forFolder:self.path];
				[self.database cacheOriginalFlagsFromMessage:message inFolder:self.path];
				self.hadChanges = YES;
				if ((message.flags & MCOMessageFlagDeleted) && flagsUpdated) {
					self.hasDeletedFlags = YES;
				}
			}
		}
	}
	[self.database commit];
}

@end
