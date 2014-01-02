//
//  PSTAddressBookManager.h
//  Puissant
//
//  Created by Robert Widmann on 4/6/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/mailcore.h>
#import <AddressBook/AddressBook.h>

/**
 * Manages ABAddressBook loading and unloading as well as an internal cache of addresses.  All work
 * is done off the main thread, so those that want to interact with the address book manager need to
 * listen for 
 */

@interface PSTAddressBookManager : NSObject

+ (instancetype)sharedManager;

/**
 * Adds an address to the address array and enqueues it for caching.
 */
- (void)addAddress:(MCOAddress *)address;

/**
 * Adds an array of addresses to the address array and enqueues them for caching.
 */
- (void)addAddresses:(NSArray *)addressObjects;

/**
 * Brings the provided address to the top of the caching queue and enqueues it for caching.
 */
- (void)cacheAddress:(MCOAddress *)address;

/**
 * Brings the provided array of addresses to the top of the caching queue and enqueues them for 
 * caching.
 */
- (void)cacheAddresses:(NSArray *)addressObjects;

/**
 * Performs a frighteningly slow search of the address book for any combinations of names or 
 * emails prefixed with the query string.  
 * Results are returned in the format "email <name>" or "name <email>"
 */
- (NSArray *)search:(NSString *)query;

/**
 * Returns an array of all the addresses present in ABAddressBook plus the internal address cache.
 */
- (NSArray *)addresses;

- (void)initializeAddressBook;

@end

@interface PSTAddressBookManager (PSTABPersonSearch)

- (ABPerson *)personForEmail:(NSString *)email;

@end
