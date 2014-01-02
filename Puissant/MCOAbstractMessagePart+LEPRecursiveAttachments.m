//
//  MCOAbstractMessagePart+LEPRecursiveAttachments.m
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "MCOAbstractMessagePart+LEPRecursiveAttachments.h"
#import "MCOAbstractPart+LEPRecursiveAttachments.h"
#import "PSTMustacheTemplate.h"
#import "MCOIMAPMessage+PSTExtensions.h"
#import "MCOMessageHeader+PSTExtensions.h"

@implementation MCOAbstractMessagePart (LEPRecursiveAttachments)

#pragma mark - LEPRecursiveAttachments

- (NSArray *)allAttachments {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [self.mainPart allAttachments]) {
		[result addObjectsFromArray:[attachment allAttachments]];
	}
	return result;
}

- (NSArray *)plaintextTypeAttachments {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [self.mainPart allAttachments]) {
		[result addObjectsFromArray:[attachment plaintextTypeAttachments]];
	}
	return result;
}

- (NSArray *)attachmentsWithContentIDs {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [self.mainPart allAttachments]) {
		[result addObjectsFromArray:[attachment attachmentsWithContentIDs]];
	}
	return result;
}

- (NSArray *)calendarTypeAttachments {
	NSMutableArray *result = [NSMutableArray array];
	
	for (MCOAbstractPart *attachment in [self.mainPart allAttachments]) {
		[result addObjectsFromArray:[attachment calendarTypeAttachments]];
	}
	return result;
}

@end

@implementation MCOAbstractMessagePart (PSTMustacheRendering)


- (NSDictionary *)dmTemplateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)UUID isDraft:(BOOL)draft {
	return [self dmTemplateValuesWithAccount:account withUUID:UUID withColorMapping:nil isDraft:draft];
}

- (NSDictionary *)dmTemplateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)UUID withColorMapping:(id)mapping isDraft:(BOOL)draft {
	return [self.header dmTemplateValuesWithAccount:account withUUID:UUID withColorMapping:mapping isDraft:draft attachments:[self.mainPart allAttachments] attachmentsWithContentIDs:[self.mainPart attachmentsWithContentIDs]];
}

- (NSDictionary *)dmMutableTemplateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)UUID isDraft:(BOOL)draft {
	return [self dmMutableTemplateValuesWithAccount:account withUUID:UUID withColorMapping:nil isDraft:draft];
}

- (NSDictionary *)dmMutableTemplateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)UUID withColorMapping:(id)mapping isDraft:(BOOL)draft {
	return [self.header dmMutableTemplateValuesWithAccount:account withUUID:UUID withColorMapping:mapping isDraft:draft attachments:[self.mainPart allAttachments] attachmentsWithContentIDs:[self.mainPart attachmentsWithContentIDs]];
}

@end
