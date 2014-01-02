//
//  PSTAddMessagesUIDsOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/21/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPFolder;

/**
 * A concrete subclass of PSTStorageOperation that adds a batch of messages UIDs to the database.  
 * This operation should be used before a PSTAddMessagesOperation to guarantee that a cache of 
 * incomplete messages can be fetched safely at a later date.
 * Note: All properties are required except where noted.
 */

@interface PSTAddMessagesUIDsOperation : PSTStorageOperation

- (void)start:(void(^)(void))callback;

/**
 * An array of messages with UIDs to insert into the database's UID cache.
 */
@property (nonatomic, copy) NSIndexSet *messages;

/**
 * Returns the last UID found from the given array of messages.
 */
@property (nonatomic, assign, readonly) NSUInteger lastUID;

@property (nonatomic, strong) MCOIMAPFolder *folder;

@end
