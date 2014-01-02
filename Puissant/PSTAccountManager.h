//
//  PSTAccountManager.h
//  DotMail
//
//  Created by Robert Widmann on 10/19/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSTMailAccount;

/*!
 * The Account Manager class for DotMail that manages an array of PSTMailAccount 
 * objects. It is responsible for de-archiving and loading it's account objects 
 * from the DotMail user deafults. It also manages the accounts "hash", or the 
 * format into which accounts will be saved
 */
@interface PSTAccountManager : NSObject

/*!
 * Returns an initialized Account Manager object.
 */
+ (instancetype)defaultManager;

- (void)initializeAccounts;

/*!
 * Inserts the account into the array of accounts as well as the accounts hash 
 * and broadcasts a change in the accounts list.
 */
- (BOOL)addAccount:(PSTMailAccount *)account;

/*!
 * Inserts the account from the array of accounts as well as the accounts hash and broadcasts a
 * change in the accounts list.
 */
- (void)removeAccount:(PSTMailAccount *)account;

/*!
 * Returns the PSTMailAccount that has the given email address.
 */
- (PSTMailAccount *)accountForEmail:(NSString *)email;

/*!
 * Flushes all changes to accounts to the disk.
 */
- (void)synchronize;

/*!
 * An array of PSTMailAccounts representing all known accounts.
 * This property is KVO Compliant
 */
@property (nonatomic, strong, readonly) NSMutableArray *accounts;

@end

/// Posted when the account manager has added or removed accounts.
PUISSANT_EXPORT NSString *const PSTAccountManagerAccountListChangedNotification;
