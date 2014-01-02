//
//  PSTUpdateActionstepsOperation.m
//  Puissant
//
//  Created by Robert Widmann on 2/8/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTUpdateActionstepsOperation.h"
#import "PSTDatabase.h"
#import "PSTDatabaseController+Operations.h"
#import "PSTMailAccount.h"

@implementation PSTUpdateActionstepsOperation

- (void)mainRequest {
	[self.database beginTransaction];
	[self.database updateActionstepsForConversationID:self.conversationID actionStep:self.actionStep];
	[self.database commit];
	
	NSUInteger count = [self.database countForNextStepsNotInTrashFolderPath:nil];
	[self.database setCountForNextSteps:count];
	[self.storage setCachedCountForNextSteps:count];
}

- (void)mainFinished {
	[NSNotificationCenter.defaultCenter postNotificationName:PSTMailAccountActionStepCountUpdated object:nil];
}

@end
