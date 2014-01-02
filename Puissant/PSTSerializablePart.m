//
//  PSTSerializablePart.m
//  Puissant
//
//  Created by Robert Widmann on 6/30/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTSerializablePart.h"
#import "PSTMailAccount.h"

@implementation PSTSerializablePart

+ (instancetype)serializablePartWithPart:(MCOIMAPPart *)part {
	return [[[self class]alloc]initWithPart:part];
}

- (id)initWithPart:(MCOIMAPPart *)part {
	self = [super init];
	
	self.encoding = part.encoding;
	self.size = part.size;
	self.partID = part.partID;
	self.filename = part.filename;
	self.mimeType = part.mimeType;

	return self;
}

- (NSDictionary *)templateValuesWithAccount:(PSTMailAccount *)account {
	NSMutableDictionary *templateValues = [[NSMutableDictionary alloc]init];


	if (self.filename != nil) {

	}
	return templateValues;
}


- (BOOL)isPlainTextAttachment {
	BOOL result = YES;
	if (![[self.mimeType lowercaseString] isEqualToString:@"text/html"]) {
		result = [[self.mimeType lowercaseString] isEqualToString:@"text/plain"];
	}
	return result;
}

#pragma mark - LEPRecursiveAttachments

- (NSArray *)plaintextTypeAttachments {
	if ([self isPlainTextAttachment]) {
		return [NSArray arrayWithObject:self];
	}
	else {
		return [NSArray array];
	}
	return nil;
}

- (NSArray *)attachmentsWithContentIDs {
	if (![self isPlainTextAttachment]) {
		if (self.partID != nil) {
			return [NSArray array];
		}
		else {
			return [NSArray arrayWithObject:self];
		}
	}
	return [NSArray array];
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super init]) {
		
		self.encoding = [decoder decodeInt32ForKey:@"encoding"];
		self.size = [decoder decodeInt32ForKey:@"size"];
		self.partID = [decoder decodeObjectForKey:@"partID"];
		self.filename = [decoder decodeObjectForKey:@"filename"];
		self.mimeType = [decoder decodeObjectForKey:@"mimeType"];
		
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:self.partID forKey:@"partID"];
	[encoder encodeInt32:self.size forKey:@"size"];
	[encoder encodeInt32:self.encoding forKey:@"encoding"];
	[encoder encodeObject:self.filename forKey:@"filename"];
	[encoder encodeObject:self.mimeType forKey:@"mimeType"];
}

@end
