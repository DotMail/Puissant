//
//  PSTConversationFetchOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/24/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTConversationFetchOperation.h"
#import "PSTDatabase.h"
#import "PSTConversation.h"

@interface PSTConversationFetchOperation ()


@end

@implementation PSTConversationFetchOperation {
	void(^_callback)(NSArray *conversations);
	NSMutableArray *conversations;
}

- (void)start:(void(^)(NSArray *conversations))callback {
	_callback = callback;
	[super startRequest];
}

- (void)mainRequest {
	if (self.isCancelled) {
		return;
	}
	switch (self.mode) {
		case PSTConversationsFetchModeNormal:
			conversations = [self.database conversationsForFolder:self.folder otherFolder:self.otherFolder allMailFolder:NO limit:self.limit];
			break;
		case PSTConversationsFetchModeAllMail:
			conversations = [self.database conversationsForFolder:self.folder otherFolder:self.otherFolder allMailFolder:YES limit:self.limit];
			break;
		case PSTConversationsFetchModeTrash:
			conversations = [self.database conversationsForFolder:self.folder otherFolder:self.otherFolder allMailFolder:NO limit:self.limit];
			break;
		case PSTConversationsFetchModeStarred:
			conversations = [self.database starredConversationsNotInTrashFolder:self.otherFolder limit:self.limit];
			break;
		case PSTConversationsFetchModeUnread:
			conversations = [self.database unreadConversationsForFolder:self.folder otherFolder:self.otherFolder limit:self.limit];
			self.existingConversations = [self.database conversationsNotInTrashFolder:self.otherFolder limit:self.limit];
			break;
		case PSTConversationsFetchModeNextSteps:
			conversations = [self.database nextStepsConversationsOperationNotInTrashFolder:self.trashFolder limit:self.limit];
			break;
		case PSTConversationFetchModeFacebookMessages:
			conversations = [self.database facebookNotificationsNotInTrash:self.trashFolder limit:self.limit];
			[conversations makeObjectsPerformSelector:@selector(setStorage:) withObject:self.storage];
			break;
		case PSTConversationFetchModeTwitterMessages:
			conversations = [self.database twitterNotificationsNotInTrash:self.trashFolder limit:self.limit];
			[conversations makeObjectsPerformSelector:@selector(setStorage:) withObject:self.storage];
			break;
		default:
			break;
	}
}

- (void)mainFinished {
	if (_callback) {
		_callback(conversations);
	}
}

@end
