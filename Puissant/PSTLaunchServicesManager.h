//
//  PSTLaunchServicesManager.h
//  Puissant
//
//  Created by Robert Widmann on 7/12/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Manages the launch services of a particular application.  Upon 
 * initialization, this class will auto-detect and cache the bundle ID and path
 * it is contained within.
 */
@interface PSTLaunchServicesManager : NSObject

/**
 * The default initializer for this class.
 */
+ (instancetype)defaultManager;

/**
 * Creates a new entry in the startup items list for the current application if 
 * one does not already exist.
 */
- (void)insertCurrentApplicationInStartupItems:(BOOL)hideAtLaunch;

/**
 * Removes the current application from the list of startup items.
 */
- (void)removeCurrentApplicationFromStartupItems;

@end

@interface PSTLaunchServicesManager (PSTEmailHandlers)

/**
 * Overrides whatever the user's last choice of application to handle the
 * `mailto` and `message` commands and sets the current application as handlers
 * for them.
 *
 * Returns TRUE on successful assertion, else false.
 */
- (BOOL)assertCurrentApplicationAsDefaultHandlerForEmail;

/**
 * Revokes the current application's status as the handler for the `mailto` and 
 * `message` commands if it is currently the handler for them and reasserts
 * Mail.app as the default handler.
 *
 * Returns TRUE on successful re-instatement, else false.
 */
- (BOOL)revokeCurrentApplicationAsDefaultHandlerForEmail;

/**
 * A convenience function to toggle between the current application and Mail.app
 * as the default handlers for the `mailto` and `message` commands.
 *
 * Returns TRUE on successful assertion, else false.
 */
- (BOOL)toggleCurrentApplicationAsDefaultHandlerForEmail;

/**
 * Returns whether or not the current application is the handler for the 
 * `mailto` and `message` commands
 */
- (BOOL)isCurrentApplicationRegisteredAsDefaultHandlerForEmail;

@end