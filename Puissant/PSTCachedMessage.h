//
//  PSTMessageCache.h
//  Puissant
//
//  Created by Robert Widmann on 11/2/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/mailcore.h>

/**
 * An abstract class that represents any message object to a cache or a cell.  PSTConversationCaches 
 * may only contain this type of object.
 */

@class MCOIMAPMessage, PSTSerializableMessage;

@interface PSTCachedMessage : NSObject <NSCoding>

@property (nonatomic, copy, readonly) NSString *subject;
@property (nonatomic, strong, readonly) NSDate *date;
@property (nonatomic, strong, readonly) NSDate *internalDate;
@property (nonatomic, strong, readonly) MCOAddress * sender;
@property (nonatomic, strong, readonly) MCOAddress * from;
@property (nonatomic, strong, readonly) NSMutableArray * recipients;
@property (nonatomic, strong, readonly) NSArray * references;
@property (nonatomic, copy, readonly) NSString *messageID;
@property (nonatomic, assign, readonly) NSUInteger folderID;
@property (nonatomic, assign, readonly) NSUInteger rowID;
@property (nonatomic, assign, readonly) uint32_t uid;
@property (nonatomic, assign) MCOMessageFlag flags;
@property (nonatomic, strong, readonly) NSArray *mainParts;
@property (nonatomic, strong, readonly) NSArray *attachments;
@property (nonatomic, strong, readonly) NSArray *inReplyTo;
@property (nonatomic, strong) NSString *folder;

/**
 * Returns an initialized Message Cache with the given attributes.
 */
- (id)initWithMessage:(PSTSerializableMessage *)cachedMessage rowID:(NSUInteger)rowID folderID:(NSUInteger)folderID;

/**
 * Returns the unique ID associated with this cache.
 */
- (NSString *)uniqueMessageIdentifer;

@end
