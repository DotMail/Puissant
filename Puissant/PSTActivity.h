//
//  PSTActivity.h
//  DotMail
//
//  Created by Robert Widmann on 11/18/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//


/**
 * A class that can represent an activity that Puissant is performing internally,
 * along with it's progress.
 */
#import <Foundation/Foundation.h>

@interface PSTActivity : NSObject

/*!
 * Returns an initialized activity with the given description and email address.  Any of these
 * properties are allowed to be nil, but it is not recommended that they be.  This differs from the
 * standard initializer in that it auto-queues the action on the default action stack.
 */
+ (PSTActivity *)activityWithDescription:(NSString *)desc forEmail:(NSString *)email;

/*!
 * Returns an initialized activity with the given description and folder path.  Any of these
 * properties are allowed to be nil, but it is not recommended that they be.  This differs from the
 * standard initializer in that it auto-queues the action on the default action stack.
 */
+ (PSTActivity *)activityWithDescription:(NSString *)desc forFolderPath:(NSString *)forFolderPath email:(NSString *)email;

/*!
 * Returns an initialized activity with the given description and email address.  Any of these
 * properties are allowed to be nil, but it is not recommended that they be,
 */
- (id)initWithDescription:(NSString *)desc forEmail:(NSString *)email;

/*!
 * Changes the progress value of the activity by a given delta value.
 */
- (void)incrementProgressValue:(float)delta;

/*!
 * Changes the meta progress value of the activity by a given delta value.
 */
- (void)incrementMetaProgressValue:(float)delta;

/*!
 * Returns (progressValue / maximumProgress), unless maximumProgress is zero, in which case it
 * returns 0 (to avoid dividing by zero).
 */
- (float)percentValue;

/*!
 * Returns (metaProgressValue / maximumMetaProgress), unless maximumMetaProgress is zero, in which case it
 * returns 0 (to avoid dividing by zero).
 */
- (float)metaPercentValue;

/**
 * The email address of the account this activity belongs to.
 */
@property (nonatomic, copy) NSString *email;

/**
 * The folder path of the folder this activity belongs to.
 */
@property (nonatomic, copy) NSString *folderPath;

/**
 * A unique identifier for this activity.
 */
@property (nonatomic, copy) NSString *activityID;

/**
 * The description of this activity.
 */
@property (nonatomic, copy) NSString *activityDescription;

/**
 * The maximum progress of this activity
 */
@property (nonatomic, assign) float maximumProgress;

/**
 * The progress of this activity
 */
@property (nonatomic, assign) float progressValue;

/**
 * The maximum meta-progress of this activity
 */
@property (nonatomic, assign) float maximumMetaProgress;

/**
 * The meta-progress of this activity
 */
@property (nonatomic, assign) float metaProgressValue;

/**
 * Returns whether the activity has finished or not
 */
@property (nonatomic, assign, getter = isFinished) BOOL finished;

@end