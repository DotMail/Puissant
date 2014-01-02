//
//  PSTMessageCache.m
//  Puissant
//
//  Created by Robert Widmann on 11/2/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTCachedMessage.h"
#import "NSString+PSTURL.h"
#import "PSTSerializableMessage.h"

@interface PSTCachedMessage ()

@property (nonatomic, copy) NSString *subject;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSDate *internalDate;
@property (nonatomic, strong) MCOAddress * sender;
@property (nonatomic, strong) MCOAddress * from;
@property (nonatomic, strong) NSMutableArray * recipients;
@property (nonatomic, copy) NSString *messageID;
@property (nonatomic, assign) NSUInteger folderID;
@property (nonatomic, assign) NSUInteger rowID;
@property (nonatomic, assign) uint32_t uid;
@property (nonatomic, strong) NSArray *mainParts;
@property (nonatomic, strong) NSArray *attachments;
@property (nonatomic, strong) NSArray * references;
@property (nonatomic, strong) NSArray * inReplyTo;

@end

@implementation PSTCachedMessage

- (id)initWithMessage:(PSTSerializableMessage *)cachedMessage rowID:(NSUInteger)rowID folderID:(NSUInteger)folderID {
	self = [super init];
	
	self.subject = cachedMessage.subject;
	self.date = cachedMessage.date;
	self.internalDate = cachedMessage.internalDate;
	self.sender = cachedMessage.sender;
	self.from = cachedMessage.from;
	self.sender = cachedMessage.sender;
	self.recipients = cachedMessage.recipients;
	self.uid = cachedMessage.uid;
	self.rowID = rowID;
	self.folderID = folderID;
	self.flags = cachedMessage.flags;
	self.messageID = cachedMessage.messageID;
	self.mainParts = cachedMessage.mainParts;
	self.attachments = cachedMessage.attachments;
	self.inReplyTo = cachedMessage.inReplyTo;
	self.references = cachedMessage.references;
	
	return self;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super init];
	
	self.inReplyTo = [aDecoder decodeObjectForKey:@"inReplyTo"];
	self.references = [aDecoder decodeObjectForKey:@"references"];
	self.subject = [aDecoder decodeObjectForKey:@"subject"];
	self.date = [aDecoder decodeObjectForKey:@"date"];
	self.internalDate = [aDecoder decodeObjectForKey:@"internalDate"];
	if (self.internalDate == nil) {
		self.internalDate = self.date;
	}
	self.sender = [aDecoder decodeObjectForKey:@"sender"];
	self.from = [aDecoder decodeObjectForKey:@"from"];
	self.recipients = [aDecoder decodeObjectForKey:@"recipients"];
	self.folderID = [aDecoder decodeInt64ForKey:@"folderID"];
	self.rowID = [aDecoder decodeInt64ForKey:@"rowID"];
	self.uid = [aDecoder decodeInt64ForKey:@"uid"];
	self.flags = [aDecoder decodeInt32ForKey:@"flags"];
	self.messageID = [aDecoder decodeObjectForKey:@"messageID"];
	self.attachments = [aDecoder decodeObjectForKey:@"attachments"];
	self.mainParts = [aDecoder decodeObjectForKey:@"mainParts"];

	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:self.subject forKey:@"subject"];
	[aCoder encodeObject:self.date forKey:@"date"];
	[aCoder encodeObject:self.internalDate forKey:@"internalDate"];
	[aCoder encodeObject:self.sender forKey:@"sender"];
	[aCoder encodeObject:self.from forKey:@"from"];
	[aCoder encodeObject:self.recipients forKey:@"recipients"];
	[aCoder encodeInt64:self.folderID forKey:@"folderID"];
	[aCoder encodeInt64:self.rowID forKey:@"rowID"];
	[aCoder encodeInt32:self.uid forKey:@"uid"];
	[aCoder encodeInt32:self.flags forKey:@"flags"];
	[aCoder encodeObject:self.messageID forKey:@"messageID"];
	[aCoder encodeObject:self.attachments forKey:@"attachments"];
	[aCoder encodeObject:self.mainParts forKey:@"mainParts"];
	[aCoder encodeObject:self.inReplyTo forKey:@"inReplyTo"];
	[aCoder encodeObject:self.references forKey:@"references"];
}

#pragma mark Internal

- (NSComparisonResult)compare:(PSTCachedMessage *)otherObject {
	return [self.internalDate compare:otherObject.internalDate];
}

- (NSString *)uniqueMessageIdentifer {
	return [NSString stringWithFormat:@"%@-%f", [self.messageID dmEncodedURLValue], [self.date timeIntervalSince1970]];
}


@end
