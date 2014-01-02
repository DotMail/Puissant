//
//  MCOAbstractPart+LEPRecursiveAttachments.m
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "MCOAbstractPart+LEPRecursiveAttachments.h"
#import "PSTMimeManager.h"
#import "PSTMailAccount.h"
#import <MailCore/MailCore.h>

@implementation MCOAbstractPart (LEPRecursiveAttachments)

- (BOOL)isPlainTextAttachment {
	BOOL result = YES;
	if (![[self.mimeType lowercaseString] isEqualToString:@"text/html"]) {
		result = [[self.mimeType lowercaseString] isEqualToString:@"text/plain"];
	}
	return result;
}

#pragma mark - LEPRecursiveAttachments

- (NSArray *)allAttachments {
	return [NSArray arrayWithObject:self];
}

- (NSArray *)plaintextTypeAttachments {
	if ([self isPlainTextAttachment]) {
		return [NSArray arrayWithObject:self];
	}
	else {
		return [NSArray array];
	}
	return nil;
}

- (NSArray *)calendarTypeAttachments {
	if ([self.mimeType.lowercaseString isEqualToString:@"text/calendar"]) {
		return [NSArray arrayWithObject:self];
	}
	return [NSArray array];
}

- (NSArray *)attachmentsWithContentIDs {
	if (![self isPlainTextAttachment]) {
		if (self.contentID != nil) {
			return [NSArray array];
		}
		else {
			return [NSArray arrayWithObject:self];
		}
	}
	return [NSArray array];
}

@end

@implementation MCOAbstractPart (PSTMustacheRendering)

- (NSDictionary *)dmTemplateValuesWithAccount:(PSTMailAccount *)account {
	return [self dmTemplateValuesWithAccount:account filename:nil];
}

- (NSDictionary *)dmTemplateValuesWithAccount:(PSTMailAccount *)account filename:(NSString *)filename {
	NSMutableDictionary *templateValues = [[NSMutableDictionary alloc]init];
	[templateValues setObject:self.contentID forKey:@"PART_ID"];
	[templateValues setObject:self.uniqueID forKey:@"MESSAGE_ID"];
	if ([PSTMimeManager.sharedManager isFileTypeImage:self.mimeType]) {

	}
	if (self.filename != nil) {

	}
	return templateValues;
}

- (void)dmPreviewString:(NSMutableString *)str account:(PSTMailAccount *)account webView:(WebView *)webView hideQuoted:(BOOL)hideQ message:(MCOIMAPMessage *)message withAttachments:(NSArray *)attachments printing:(BOOL)forPrinting {
	char *cStr = (char *)[account dataForAttachment:self atPath:@"INBOX"].bytes;
	if (cStr == NULL) cStr = "";
	NSString *rendering = [NSString stringWithCString:cStr encoding:NSUTF8StringEncoding];
	if (rendering.length == 0) {
		rendering = [NSString stringWithCString:cStr encoding:NSASCIIStringEncoding];
	}
	if (rendering.length) [str appendString:[rendering mco_cleanedHTMLString]];
}

@end

@implementation MCOAbstractMultipart (LEPRecursiveAttachments)

- (NSArray *)allAttachments {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [self parts]) {
		[result addObjectsFromArray:[attachment allAttachments]];
	}
	return result;
}

- (NSArray *)plaintextTypeAttachments {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [self parts]) {
		[result addObjectsFromArray:[attachment plaintextTypeAttachments]];
	}
	return result;
}

- (NSArray *)attachmentsWithContentIDs {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [self parts]) {
		[result addObjectsFromArray:[attachment attachmentsWithContentIDs]];
	}
	return result;
}

- (NSArray *)calendarTypeAttachments {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [self parts]) {
		[result addObjectsFromArray:[attachment calendarTypeAttachments]];
	}
	return result;
}
@end
