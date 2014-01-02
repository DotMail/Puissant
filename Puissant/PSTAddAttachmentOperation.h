//
//  PSTAddAttachmentOperation.h
//  Puissant
//
//  Created by Robert Widmann on 11/21/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOAbstractMessage;

/**
 * A concrete subclass of PSTStorageOperation that associates a given attachment's data with a 
 * message, and writes it's data to file if necessary.  Not all fields are required, but where noted
 * should always be non-nil in order for the request to execute properly.
 */

@interface PSTAddAttachmentOperation : PSTStorageOperation

/**
 * The attachment data to write to the database.
 * Note: This is a required property.
 */
@property (nonatomic, strong) NSData *data;

/**
 * The message to associate this attachment with.  
 * Note: This is a required property.
 */
@property (nonatomic, strong) MCOAbstractMessage *message;

/**
 * The part ID of the attachment.
 */
@property (nonatomic, strong) NSString *partID;

/**
 * The filename of the attachment.  If provided, there is a stronger chance the database will choose
 * to write it to file.
 */
@property (nonatomic, strong) NSString *filename;

/**
 * The MIME type of the given attachment.
 */
@property (nonatomic, strong) NSString *mimeType;

/**
 * The folder path of the reciever.
 */
@property (nonatomic, strong) NSString *path;

@end
