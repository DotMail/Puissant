//
//  PSTLocalMessage.m
//  Puissant
//
//  Created by Robert Widmann on 11/22/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTLocalMessage.h"
#import "PSTLocalAttachment.h"
#import "PSTMailAccount.h"
#import <MailCore/MCOMessageHeader.h>

@class WebView;

@implementation PSTLocalMessage

- (id)init {
	self = [super init];
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
	PSTLocalMessage *message = [super copyWithZone:zone];
	[message setFolder:self.folder];
	[message setFlags:self.flags];
	return message;
}

//- (id)initWithCoder:(NSCoder *)aDecoder {
//	if (self = [super initWithCoder:aDecoder]) {
//		self.flags = [aDecoder decodeIntForKey:@"flags"];
//	}
//	return self;
//}
//
//- (void)encodeWithCoder:(NSCoder *)aCoder {
//	[super encodeWithCoder:aCoder];
//	[aCoder encodeInt:self.flags forKey:@"flags"];
//	[[self data] writeToFile:[self _path] atomically:YES];
//}

- (void)setOriginalFlags:(MCOMessageFlag)originalFlags {
	self.flags = originalFlags;
}

- (MCOMessageFlag)originalFlags {
	return self.flags;
}

- (uint64_t)estimatedSize {
	uint64_t size = 0;
	for (MCOAttachment *attachment in [self attachments]) {
		size += attachment.data.length;
	}
	return size;
}

- (void)setFolderPath:(NSString *)folderPath {
	_folderPath = folderPath;
	for (id attachment in [self attachments]) {
		if ([attachment isKindOfClass:[PSTLocalAttachment class]]) {
			[(PSTLocalAttachment*)attachment setFolderPath:folderPath];
		}
	}
}

- (void)commit {
	for (id attachment in [self attachments]) {
		if ([attachment isKindOfClass:[PSTLocalAttachment class]]) {
			[(PSTLocalAttachment*)attachment commit];
		}
	}
}

- (NSString *)_path {
	return [self.folderPath stringByAppendingPathComponent:[self.header.messageID stringByAppendingPathExtension:@"eml"]];
}

- (void)remove {
	[[NSFileManager defaultManager]removeItemAtPath:[self _path] error:nil];
	for (id attachment in [self attachments]) {
		if ([attachment isKindOfClass:[PSTLocalAttachment class]]) {
			[(PSTLocalAttachment*)attachment remove];
		}
	}
}

- (BOOL)isValid {
	BOOL result = YES;
	for (id attachment in [self attachments]) {
		if (![attachment isKindOfClass:[PSTLocalAttachment class]]) {
			continue;
		}
		if (self.data == nil) {
			return NO;
		}
	}
	return result;
}

@end
