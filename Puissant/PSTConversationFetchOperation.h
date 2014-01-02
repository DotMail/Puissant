//
//  PSTConversationsFetchOperation.h
//  DotMail
//
//  Created by Robert Widmann on 10/21/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPFolder;

typedef NS_ENUM(NSUInteger, PSTConversationsFetchMode) {
	PSTConversationsFetchModeNormal,
	PSTConversationsFetchModeAllMail,
	PSTConversationsFetchModeTrash,
	PSTConversationsFetchModeStarred,
	PSTConversationsFetchModeUnread,
	PSTConversationsFetchModeNextSteps,
	PSTConversationFetchModeFacebookMessages,
	PSTConversationFetchModeTwitterMessages
};

/**
 * A concrete subclass of PSTStorageOperation that fetches a certain subset of messages depending on 
 * it's mode and the folders it's provided.
 * Note: All properties are required except where noted.
 */

@interface PSTConversationFetchOperation : PSTStorageOperation

- (void)start:(void(^)(NSArray *conversations))callback;

@property (nonatomic, assign) BOOL fullConversationsLoadAfterPartial;
@property (nonatomic, assign) NSUInteger limit;
@property (nonatomic, strong) MCOIMAPFolder *folder;
@property (nonatomic, strong) MCOIMAPFolder *otherFolder;
@property (nonatomic, strong) MCOIMAPFolder *allMailFolder;
@property (nonatomic, strong) MCOIMAPFolder *trashFolder;
@property (nonatomic, strong) MCOIMAPFolder *importantFolder;
@property (nonatomic, strong) NSMutableArray *existingConversations;
@property (nonatomic, assign) PSTConversationsFetchMode mode;

@end
