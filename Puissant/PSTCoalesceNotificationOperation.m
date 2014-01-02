//
//  PSTCoalesceNotificationOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTCoalesceNotificationOperation.h"
#import "PSTDatabase.h"

@interface PSTCoalesceNotificationOperation ()

@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSArray *conversationIDs;

@end

@implementation PSTCoalesceNotificationOperation {
	void(^_callback)(NSArray *messages, NSArray *conversationIDs);
}

- (void)start:(void(^)(NSArray *messages, NSArray *conversationIDs))callback {
	_callback = callback;
	[super startRequest];
}

- (void)mainRequest {
	NSDictionary *notifyDictionary = [self.database messagesNeedingNotificationForFolder:self.folder];
	self.messages = notifyDictionary[@"Messages"];
	self.conversationIDs = notifyDictionary[@"ConversationIDs"];
}

- (void)mainFinished {
	if (_callback) {
		_callback(self.messages, self.conversationIDs);
	}
}

@end
