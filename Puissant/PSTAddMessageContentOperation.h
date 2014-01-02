//
//  PSTAddMessageContentOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/21/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOAbstractMessage;

/**
 * A concrete subclass of PSTStorageOperation that associates a given attachment's data with a
 * message's body, and writes it's data to the database.  Body content is the only acceptable data
 * to use for this operation, as using it will reload the preview for a given message cache.
 * Note: All properties are required.
 */

@interface PSTAddMessageContentOperation : PSTStorageOperation

/**
 * The attachment data to write to the database.
 * Note: This is a required property.
 */
@property (nonatomic, strong) NSData *data;

/**
 * The message to associate the reciever with in the database.
 */
@property (nonatomic, strong) MCOAbstractMessage *message;

/**
 * The folder path of the reciever.
 */
@property (nonatomic, strong) NSString *path;

@end
