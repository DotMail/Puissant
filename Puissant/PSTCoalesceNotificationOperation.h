//
//  PSTCoalesceNotificationOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPFolder;

/**
 * A concrete subclass of PSTStorageOperation that fetches the conversation ID of conversations that
 * the user has not been informed about by notification.
 * Note: All properties are required except where noted.
 */

@interface PSTCoalesceNotificationOperation : PSTStorageOperation

/**
 * The folder to search for un-notified conversations.
 */
@property (nonatomic, strong) MCOIMAPFolder *folder;

- (void)start:(void(^)(NSArray *messages, NSArray *conversationIDs))callback;

@end
