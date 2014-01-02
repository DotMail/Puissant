//
//  PSTActivityManager.h
//  DotMail
//
//  Created by Robert Widmann on 11/18/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSTActivity;

/**
 * A singleton that manages a stack of activities.
 */
@interface PSTActivityManager : NSObject

/**
 * The activities that are currently scheduled.
 */
@property (nonatomic, strong, readonly) NSMutableArray *activities;

/**
 * Returns an initialized activity manager.
 */
+ (PSTActivityManager *)sharedManager;

/**
 * Registers an activity and adds it to the stack.
 */
- (void)registerActivity:(PSTActivity *)activity;

/**
 * De-registers an activity, marks it as finished, and removes it from the stack.
 */
- (void)removeActivity:(PSTActivity *)activity;

/**
 * Removes all activities associated with an email address from the stack, then 
 * removes itself as the observer for those activities.
 */
- (void)clearAllActivitiesFromAccount:(NSString *)email;

/**
 * Removes all activities from the stack, then removes itself as the observer for those activities.
 */
- (void)clearAllActivities;

/**
 * Sends the PSTActivityManagerDidUpdateNotification notification out to it's observers.
 */
- (void)broadcastUpdate;

@end
