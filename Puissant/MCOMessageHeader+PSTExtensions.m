//
//  MCOMessageHeader+PSTExtensions.m
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "MCOMessageHeader+PSTExtensions.h"
#import "NSString+PSTURL.h"
#import "MCOAbstractPart+LEPRecursiveAttachments.h"

@implementation MCOMessageHeader (PSTExtensions)

- (NSString *)uniqueMessageIdentifer {
	return [NSString stringWithFormat:@"%@-%f", [self.messageID dmEncodedURLValue], [[NSDate date] timeIntervalSince1970]];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super init];
	
	self.messageID = [decoder decodeObjectForKey:@"messageID"];
	self.references = [decoder decodeObjectForKey:@"references"];
	self.inReplyTo = [decoder decodeObjectForKey:@"inReplyTo"];
	self.sender = [decoder decodeObjectForKey:@"sender"];
	self.from = [decoder decodeObjectForKey:@"from"];
	self.to = [decoder decodeObjectForKey:@"to"];
	self.cc = [decoder decodeObjectForKey:@"cc"];
	self.bcc = [decoder decodeObjectForKey:@"bcc"];
	self.replyTo = [decoder decodeObjectForKey:@"replyTo"];
	self.subject = [decoder decodeObjectForKey:@"subject"];
	self.date = [decoder decodeObjectForKey:@"date"];
	self.receivedDate = [decoder decodeObjectForKey:@"receivedDate"];
	if (self.receivedDate == nil) {
		self.receivedDate = self.date.copy;
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.messageID forKey:@"messageID"];
	[encoder encodeObject:self.references forKey:@"references"];
	[encoder encodeObject:self.inReplyTo forKey:@"inReplyTo"];
	[encoder encodeObject:self.sender forKey:@"sender"];
	[encoder encodeObject:self.from forKey:@"from"];
	[encoder encodeObject:self.to forKey:@"to"];
	[encoder encodeObject:self.cc forKey:@"cc"];
	[encoder encodeObject:self.bcc forKey:@"bcc"];
	[encoder encodeObject:self.replyTo forKey:@"replyTo"];
	[encoder encodeObject:self.subject forKey:@"subject"];
	[encoder encodeObject:self.date forKey:@"date"];
	[encoder encodeObject:self.receivedDate forKey:@"receivedDate"];
}

@end

@implementation MCOMessageHeader (PSTTemplateRendering)

- (NSDictionary *)dmTemplateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)uuid withColorMapping:(id)mapping isDraft:(BOOL)isDraft attachments:(NSArray *)attachments attachmentsWithContentIDs:(NSArray *)attsWithContentIDs {
	return [self dmMutableTemplateValuesWithAccount:account withUUID:uuid withColorMapping:mapping isDraft:isDraft attachments:attachments attachmentsWithContentIDs:attsWithContentIDs];
}

- (NSMutableDictionary *)dmMutableTemplateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)uuid withColorMapping:(id)mapping isDraft:(BOOL)isDraft attachments:(NSArray *)attachments attachmentsWithContentIDs:(NSArray *)attsWithContentIDs {

	NSMutableDictionary *templateValues = [[NSMutableDictionary alloc] init];

	[templateValues setObject:[[NSBundle mainBundle]pathForResource:@"conversation" ofType:@"js"] forKey:@"CONVERSATION_COMPILED_JS_URL"];
	[templateValues setObject:[[NSBundle mainBundle]pathForResource:@"conversation" ofType:@"css"] forKey:@"CONVERSATION_CSS_URL"];

	NSMutableArray *messageParts = @[].mutableCopy;
	for (MCOAbstractPart *part in attachments) {
		[messageParts addObject:[part dmTemplateValuesWithAccount:account]];
	}
	[templateValues setObject:messageParts forKey:@"ATTACHMENTS"];
	return templateValues;
}

@end
