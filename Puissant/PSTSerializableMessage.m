//
//  PSTSerializableMessage.m
//  Puissant
//
//  Created by Robert Widmann on 6/29/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTSerializableMessage.h"
#import "MCOAbstractMessage+LEPRecursiveAttachments.h"
#import "MCOAbstractPart+LEPRecursiveAttachments.h"
#import "PSTSerializablePart.h"
#import "NSString+PSTURL.h"
#import "NSDate+Helper.h"
#import "PSTMailAccount.h"
#import "PSTAccountController.h"
#import "MCOIMAPMessage+PSTExtensions.h"

@interface PSTSerializableMessage ()

@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSDate *internalDate;
@property (nonatomic, strong) MCOAddress * sender;
@property (nonatomic, strong) MCOAddress * from;
@property (nonatomic, strong) NSMutableArray * recipients;
@property (nonatomic, copy) NSString *messageID;
@property (nonatomic, copy) NSString *subject;
@property (nonatomic, assign) NSUInteger folderID;
@property (nonatomic, assign) NSUInteger rowID;
@property (nonatomic, assign) uint32_t uid;
@property (nonatomic, strong) NSArray *mainParts;
@property (nonatomic, strong) NSArray *attachments;
@property (nonatomic, strong) NSArray * references;
@property (nonatomic, strong) NSArray * inReplyTo;

@end

PUISSANT_TODO(Replace with archiving MCOIMAPMessage directly)

@implementation PSTSerializableMessage

+ (instancetype)serializableMessageWithMessage:(MCOAbstractMessage *)message {
	if ([message isKindOfClass:PSTSerializableMessage.class]) return (PSTSerializableMessage *)message;
	return [[[self class]alloc]initWithMessage:message];
}

- (id)initWithMessage:(MCOIMAPMessage *)cachedMessage {	
	NSMutableArray *newmainParts = @[].mutableCopy;
	for (MCOIMAPPart *part in cachedMessage.mainPart.allAttachments) {
		[newmainParts addObject:[PSTSerializablePart serializablePartWithPart:part]];
	}
	self.mainParts = newmainParts;

	NSMutableArray *newAttachments = @[].mutableCopy;
	for (MCOIMAPPart *part in cachedMessage.allAttachments) {
		[newAttachments addObject:[PSTSerializablePart serializablePartWithPart:part]];
	}
	self.attachments = newAttachments;
	
	self.date = cachedMessage.header.date;
	self.internalDate = cachedMessage.header.receivedDate;
	self.sender = cachedMessage.header.sender;
	self.from = cachedMessage.header.from;
	self.sender = cachedMessage.header.sender;
	self.subject = cachedMessage.header.subject;
	NSMutableArray *addresses = [[NSMutableArray alloc] init];
	NSMutableSet *mailboxes = [[NSMutableSet alloc] init];
	for (MCOAddress *address in cachedMessage.header.to) {
		if (![mailboxes containsObject:address.mailbox]) {
			if (address.mailbox != nil) {
				[mailboxes addObject:address.mailbox];
				[addresses addObject:address];
			}
		}
	}
	for (MCOAddress *address in cachedMessage.header.cc) {
		if (![mailboxes containsObject:address.mailbox]) {
			if (address.mailbox != nil) {
				[mailboxes addObject:address.mailbox];
				[addresses addObject:address];
			}
		}
	}
	for (MCOAddress *address in cachedMessage.header.bcc) {
		if (![mailboxes containsObject:address.mailbox]) {
			if (address.mailbox != nil) {
				[mailboxes addObject:address.mailbox];
				[addresses addObject:address];
			}
		}
	}
	self.recipients = addresses;
	self.uid = cachedMessage.uid;
	self.flags = cachedMessage.flags;
	self.originalFlags = cachedMessage.originalFlags;
	self.messageID = cachedMessage.header.messageID;
	self.inReplyTo = cachedMessage.header.inReplyTo;
	self.references = cachedMessage.header.references;
	
	return self;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {		
	self.date = [aDecoder decodeObjectForKey:@"date"];
	self.internalDate = [aDecoder decodeObjectForKey:@"internalDate"];
	if (self.internalDate == nil) {
		self.internalDate = self.date;
	}
	self.sender = [aDecoder decodeObjectForKey:@"sender"];
	self.from = [aDecoder decodeObjectForKey:@"from"];
	self.recipients = [aDecoder decodeObjectForKey:@"recipients"];
	self.subject = [aDecoder decodeObjectForKey:@"subject"];
	self.folderID = [aDecoder decodeInt64ForKey:@"folderID"];
	self.rowID = [aDecoder decodeInt64ForKey:@"rowID"];
	self.uid = [aDecoder decodeInt64ForKey:@"uid"];
	self.flags = [aDecoder decodeInt32ForKey:@"flags"];
	self.originalFlags = [aDecoder decodeInt32ForKey:@"originalFlags"];
	self.messageID = [aDecoder decodeObjectForKey:@"messageID"];
	self.attachments = [aDecoder decodeObjectForKey:@"attachments"];
	self.mainParts = [aDecoder decodeObjectForKey:@"mainParts"];
	self.inReplyTo = [aDecoder decodeObjectForKey:@"inReplyTo"];
	self.references = [aDecoder decodeObjectForKey:@"references"];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:self.date forKey:@"date"];
	[aCoder encodeObject:self.internalDate forKey:@"internalDate"];
	[aCoder encodeObject:self.sender forKey:@"sender"];
	[aCoder encodeObject:self.from forKey:@"from"];
	[aCoder encodeObject:self.recipients forKey:@"recipients"];
	[aCoder encodeInt64:self.folderID forKey:@"folderID"];
	[aCoder encodeInt64:self.rowID forKey:@"rowID"];
	[aCoder encodeInt32:self.uid forKey:@"uid"];
	[aCoder encodeInt32:self.flags forKey:@"flags"];
	[aCoder encodeInt32:self.originalFlags forKey:@"originalFlags"];
	[aCoder encodeObject:self.messageID forKey:@"messageID"];
	[aCoder encodeObject:self.subject forKey:@"subject"];
	[aCoder encodeObject:self.attachments forKey:@"attachments"];
	[aCoder encodeObject:self.mainParts forKey:@"mainParts"];
	[aCoder encodeObject:self.inReplyTo forKey:@"inReplyTo"];
	[aCoder encodeObject:self.references forKey:@"references"];
}

- (NSComparisonResult)compare:(PSTSerializableMessage *)otherObject {
	return [self.internalDate compare:otherObject.internalDate];
}

- (NSString *)uniqueMessageIdentifer {
	return [NSString stringWithFormat:@"%@-%f", [self.messageID dmEncodedURLValue], [self.date timeIntervalSince1970]];
}

- (NSDictionary *)templateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)uuid {
	PSTMailAccount *mainAccount = (PSTMailAccount *)account;
	if ([account respondsToSelector:@selector(mainAccount)]) {
		mainAccount = ((PSTAccountController *)account).mainAccount;
	}
	
	NSMutableDictionary *templateValues = [[NSMutableDictionary alloc] init];

	[templateValues setObject:[[NSBundle mainBundle]pathForResource:@"conversation" ofType:@"js"] forKey:@"CONVERSATION_COMPILED_JS_URL"];
	[templateValues setObject:[[NSBundle mainBundle]pathForResource:@"conversation" ofType:@"css"] forKey:@"CONVERSATION_CSS_URL"];
	[templateValues setObject:self.uniqueMessageIdentifer forKey:@"MESSAGE_ID"];

	if ((self.flags & MCOMessageFlagDraft) != MCOMessageFlagDraft) {
		[templateValues setObject:@{} forKey:@"MESSAGE_IS_NORMAL"];
	} else {
		[templateValues setObject:@{} forKey:@"MESSAGE_IS_DRAFT"];
	}

	if (self.from) {
		[templateValues setObject:self.from.mailbox forKey:@"HTML_MESSAGE_FROM"];
		[templateValues setObject:@"From" forKey:@"CONVERSATION_DETAILS_FROM_LABEL"];
	}
	if (self.date) {
		[templateValues setObject:self.date.dmDotFormattedDateString forKey:@"MESSAGE_SHORT_DATE"];
	}
	if (self.recipients.count != 0) {
		[templateValues setObject:@{} forKey:@"HAS_MESSAGE_SHORT_RECIPIENT"];
		[templateValues setObject:self.from.mailbox forKey:@"HTML_MESSAGE_SHORT_FROM"];
		[templateValues setObject:[NSString stringWithFormat:@"to %@", mainAccount.name] forKey:@"HTML_MESSAGE_TO_SHORT_RECIPIENT"];
		[templateValues setObject:[NSString stringWithFormat:@"to %@", mainAccount.name] forKey:@"MESSAGE_TO_SHORT_RECIPIENT"];
	}

	NSString *bodyHTML = [self bodyHTMLRenderingWithAccount:mainAccount withWebView:nil hideQuoted:YES enableActivity:YES printing:NO inlineAttachmentEnabled:NO];
	[templateValues setObject:bodyHTML forKey:@"MESSAGE_BODY"];

	NSMutableArray *messageParts = @[].mutableCopy;
	for (PSTSerializablePart *part in self.attachmentsWithContentIDs) {
		[messageParts addObject:[part templateValuesWithAccount:account]];
	}
	
	for (PSTSerializablePart *part in self.attachments) {
		[messageParts addObject:[part templateValuesWithAccount:account]];
	}
	[templateValues setObject:messageParts forKey:@"ATTACHMENTS"];
	return templateValues;
}

- (NSString *)bodyHTMLRenderingWithAccount:(PSTMailAccount *)account withWebView:(WebView *)webview hideQuoted:(BOOL)hide enableActivity:(BOOL)activity printing:(BOOL)printing inlineAttachmentEnabled:(BOOL)inlineEnabled {
	NSMutableString *bodyString = [[NSMutableString alloc] init];
	
	PSTMailAccount *mainAccount = account;
	if ([account respondsToSelector:@selector(mainAccount)]) {
		mainAccount = ((PSTAccountController *)account).mainAccount;
	}
	if (![mainAccount hasDataForMessage:(MCOIMAPMessage *)self atPath:[self dm_folder].path]) {
		return [self mmHTMLPlaceholderShowActivity:activity];
	} else {
		char *cStr = (char *)[mainAccount dataForAttachment:PSTPreferredIMAPPart(self.mainParts) onMessage:(MCOIMAPMessage *)self atPath:[self dm_folder].path].bytes;
		if (cStr == NULL) cStr = "";
		NSString *rendering = [NSString stringWithCString:cStr encoding:NSUTF8StringEncoding];
		if (rendering.length == 0) {
			rendering = [NSString stringWithCString:cStr encoding:NSASCIIStringEncoding];
		}
		if (rendering.length) [bodyString appendString:[rendering mco_cleanedHTMLString]];
	}
	return bodyString;
}

- (NSString *)mmHTMLPlaceholderShowActivity:(BOOL)verbose {
	NSMutableString *html = [NSMutableString string];
	if (verbose) {
		[html appendFormat:@"<p style=\"text-align:left; color: #a0a0a0a0;\">%@</p>", @"The content of this message has not been downloaded yet."];
	} else {
		[html appendFormat:@"<div id=\"spinner\"><p style=\"text-align:left; color: #a0a0a0; font-weight: bold;\">Loading</p></div>"];
	}
	return html;
}

@end
