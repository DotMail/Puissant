//
//  PSTNotificationHub.h
//  Puissant
//
//  Created by Robert Widmann on 1/26/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSTSerializableMessage, PSTAccountController;

/**
 * Provides a singleton which grants access to the notifications API's.  For OS X Mountain Lion,
 * this class communicates with notification center, and for all other OSes, it communicates with
 * Growl for notifications.  Notifications are coalesced by the center, so notifications in a tight
 * loop of more than three messages will result in a concatenation of them all into one notification
 * for UX reasons.
 */

@interface PSTNotificationHub : NSObject

/**
 * Returns the default notifications hub.
 */
+ (instancetype)defaultNotificationHub;

/**
 * Returns whether this system has installed Growl or Mist.
 */
- (BOOL)isGrowlInstalled;

/**
 * Returns whether this system is 10.8+
 */
- (BOOL)isNotificationCenterEnabled;

/**
 * Adds the given message to the notification's queue for processing.
 * Note: If called in a tight loop, it will process it's queue into one unified notification.
 */
- (void)queueNotificationForMessage:(PSTSerializableMessage*)message conversationID:(long long)conversationID account:(PSTAccountController*)account;

@end
