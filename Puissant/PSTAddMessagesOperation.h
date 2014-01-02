//
//  PSTAddMessagesOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/21/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

/**
 * A concrete subclass of PSTStorageOperation that adds a batch of messages to the database.  This 
 * operation triggers a conversation gen, so it should be used sparingly.
 * Note: All properties are required.
 */

@interface PSTAddMessagesOperation : PSTStorageOperation


- (void)start:(void(^)(void))callback;

/**
 * An array of messages to insert into the database.
 */
@property (nonatomic, copy) NSArray *messages;

/**
 * The path to the folder for the given message array.
 */
@property (nonatomic, copy) NSString *path;

/**
 * Returns whether or not the array of messages to insert into the database are drafts.  If so, the 
 * database will write them to disk.
 */
@property (nonatomic, assign, getter = isDraft) BOOL draft;


@end
