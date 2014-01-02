//
//  MCOAbstractMessage+LEPRecursiveAttachments.m
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "MCOAbstractMessage+LEPRecursiveAttachments.h"
#import <MailCore/MCOAbstractPart.h>
#import <MailCore/MCOIMAPMessage.h>
#import <MailCore/MCOMessageHeader.h>
#import <MailCore/MCOAddress.h>
#import "PSTSerializableMessage.h"
#import "MCOAbstractPart+LEPRecursiveAttachments.h"

@implementation MCOAbstractMessage (LEPRecursiveAttachments)

- (NSArray *)allAttachments {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [(MCOIMAPMessage *)self attachments]) {
		[result addObjectsFromArray:[attachment allAttachments]];
	}
	return result;
}

- (NSArray *)plaintextTypeAttachments {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [(MCOIMAPMessage *)self attachments]) {
		[result addObjectsFromArray:[attachment plaintextTypeAttachments]];
	}
	return result;
}

- (NSArray *)calendarTypeAttachments {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [(MCOIMAPMessage *)self attachments]) {
		[result addObjectsFromArray:[attachment calendarTypeAttachments]];
	}
	return result;
}

- (NSArray *)attachmentsWithContentIDs {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [(MCOIMAPMessage *)self attachments]) {
		[result addObjectsFromArray:[attachment attachmentsWithContentIDs]];
	}
	return result;
}

- (BOOL)isFacebookNotification {
	if ([self isKindOfClass:MCOIMAPMessage.class]) {
		return [self.header.from.mailbox rangeOfString:@"facebookmail.com"].location != NSNotFound;
	}
	return [((PSTSerializableMessage *)self).from.mailbox rangeOfString:@"facebookmail.com"].location != NSNotFound;
}

- (BOOL)isTwitterNotification {
	if ([self isKindOfClass:MCOIMAPMessage.class]) {
		return [self.header.from.mailbox rangeOfString:@"postmaster.twitter.com"].location != NSNotFound;
	}
	return [((PSTSerializableMessage *)self).from.mailbox rangeOfString:@"postmaster.twitter.com"].location != NSNotFound;
}

@end
