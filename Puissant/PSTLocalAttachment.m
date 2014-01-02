//
//  PSTLocalAttachment.m
//  Puissant
//
//  Created by Robert Widmann on 11/16/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTLocalAttachment.h"
#import "PSTMimeManager.h"
#import "NSString+PSTUUID.h"

@interface PSTLocalAttachment ()

@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL modified;

@end

@implementation PSTLocalAttachment

+ (MCOAbstractMessage *)attachmentWithContentsOfFile:(NSString *)filename {
	return [[self alloc]initWithContentsOfFile:filename];
}

- (id)init {
	if (self = [super init]) {
		[self setMimeType:@"application/octet-stream"];
		self.partID = [NSString dmUUIDString];
	}
	return self;
}

- (id)initWithContentsOfFile:(NSString *)filename {
	self = [self init];
	NSData *data = [NSData dataWithContentsOfFile:filename];
	NSString *mimeType = [MCOAttachment mimeTypeForFilename:filename];
	if (mimeType != nil) {
		[self setMimeType:mimeType];
	}
	[self setFilename:[filename lastPathComponent]];
	[self setData:data];
	return self;
}

//- (id)initWithCoder:(NSCoder *)aDecoder {
//	if (self = [super initWithCoder:aDecoder]) {
//		self.partID = [aDecoder decodeObjectForKey:@"partID"];
//		self.modified = NO;
//	}
//	return self;
//}
//
//- (void)encodeWithCoder:(NSCoder *)aCoder {
//	[super encodeWithCoder:aCoder];
//	[aCoder encodeObject:self.partID forKey:@"partID"];
//}

- (id)copyWithZone:(NSZone *)zone {
	PSTLocalAttachment *attachment = [super copyWithZone:zone];
	attachment.partID = self.partID;
	attachment.folderPath = self.folderPath;
	attachment.data = self.data;
	attachment.loaded = self.loaded;
	attachment.modified = self.modified;
	return attachment;
}

- (void)_loadIfNeeded {
	if (self.loaded == NO) {
		self.data = [[NSData alloc]initWithContentsOfFile:[self _path]];
	}
}

- (NSUInteger)size {
	NSUInteger result = 0;
	if (self.data == nil) {
		result = [[[[NSFileManager defaultManager]attributesOfItemAtPath:[self _path] error:nil]objectForKey:NSFileSize]unsignedLongLongValue];
	} else {
		result = self.data.length;
	}
	return result;
}

- (NSString*)_path {
	return [self.folderPath stringByAppendingPathComponent:self.partID];
}

- (NSData *)data {
	if (!self.loaded) {
		NSAssert(self.folderPath != nil, @"_folderPath != nil");
		[self _loadIfNeeded];
	}
	return [super data];
}

- (void)setData:(NSData *)data {
	[super setData:data];
	self.loaded = YES;
	self.modified = YES;
}

- (void)_saveData {
	if (self.data != nil && self.loaded) {
		if (self.modified) {
			[self.data writeToFile:[self _path] atomically:YES];
		}
	}
}

- (void)commit {
	self.modified = NO;
}

- (void)remove {
	[[NSFileManager defaultManager]removeItemAtPath:[self _path] error:nil];
}

@end
