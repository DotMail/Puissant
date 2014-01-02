//
//  PSTAccountControllerManager.h
//  DotMail
//
//  Created by Robert Widmann on 10/9/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSTAccountController;
@class PSTMailAccount;

/*!
 * The Unified Account Manager for DotMail that is responsible for managing the 
 * accounts controller, and being the general liaison between the model and 
 * view.  It manages a list of PSTAccountControllers, one of which is a truly 
 * unified account.
 */
@interface PSTAccountControllerManager : NSObject

/*!
 * Returns an initialized Account Controller Manager
 */
+ (instancetype)defaultManager;

/*!
 * Returns the account controller (excludes those that contain multiple 
 * accounts) that matches the passed-in email address.
 */
- (PSTAccountController *)accountControllerForEmail:(NSString *)email;

/*!
 * Returns the account controller (excludes those that contain multiple 
 * accounts) that owns the passed-in account
 */
- (PSTAccountController *)accountControllerForAccount:(PSTMailAccount *)account;

/*!
 * Returns an array of the accounts (includes those that contain multiple 
 * accounts) that contain the passed-in email address.
 */
- (NSArray *)accountsForEmail:(NSString *)email;

/*!
 * An array of all known PSTAccountController objects.
 * This property is KVO compliant.
 */
@property (nonatomic, strong, readonly) NSArray *accounts;

@end

/*
 * Notification of a change to the PSTAccountControllerManager singleton's account list.
 */
PUISSANT_EXPORT NSString *const PSTAccountControllerManagerAccountListChangedNotification;
