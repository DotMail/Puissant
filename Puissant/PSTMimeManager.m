//
//  PSTMimeManager.m
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTMimeManager.h"

@interface PSTMimeManager ()

@property (nonatomic, retain) NSDictionary *mimeToExtensionMap;
@property (nonatomic, retain) NSDictionary *extensionToMimeMap;

@property (nonatomic, retain) NSSet *possibleImageExtensions;
@property (nonatomic, retain) NSSet *possibleImageMimeTypes;
@property (nonatomic, retain) NSSet *possibleArchivedMimeTypes;

@end

@implementation PSTMimeManager

+ (instancetype) sharedManager {
	PUISSANT_SINGLETON_DECL(PSTMimeManager);
}

- (id)init {
	self = [super init];

	self.possibleImageExtensions = [NSSet setWithArray:@[
										@"jpg", @"jpeg",
										@"png", @"gif",
										@"tiff", @"tif"
								   ]];
	self.possibleImageMimeTypes = [NSSet setWithArray:@[
										@"image/jpeg", @"image/gif", @"image/png",
										@"image/tiff", @"image/tif"
								  ]];
	
	self.possibleArchivedMimeTypes = [NSSet setWithArray:@[
										@"zip", @"sfark", @"s7z",
										@"ace", @"cpt", @"dar",
										@"pit", @"sea", @"sit",
										@"par", @"par2", @"gz",
										@"tgz", @"bz2", @"tbz",
										@"Z", @"taz", @"lz",
										@"tlz", @"7z"
									 ]];
	self.mimeToExtensionMap = @{
		@"image/jpeg": @"jpg",
		@"image/jpeg": @"jpeg",
		@"application/pdf": @"pdf",
		@"image/gif": @"gif",
		@"image/png": @"png",
		@"image/tiff": @"tiff",
		@"image/tiff": @"tif",
		@"image/bmp": @"bmp",
		@"application/zip": @"zip",
		@"text/calendar": @"ics",
		@"message/rfc822": @"eml"
	};
	self.extensionToMimeMap = @{
		@"jpg": @"image/jpeg",
		@"jpeg": @"image/jpeg",
		@"pdf": @"application/pdf",
		@"gif": @"image/gif",
		@"png": @"image/png",
		@"tiff": @"image/tiff",
		@"tiff": @"image/tif",
		@"bmp": @"image/bmp",
		@"zip": @"application/zip",
		@"ics": @"text/calendar",
		@"eml": @"message/rfc822"
	};

	return self;
}

/// Just grab the path extension.  Nothing fancy.
- (BOOL)isFileTypePDF:(NSString *)filename {
	return [filename.pathExtension.lowercaseString isEqualToString:@"pdf"];
}

- (BOOL)isMimeTypePDF:(NSString *)mimeType {
	return [mimeType.pathExtension.lowercaseString hasSuffix:@"pdf"];
}

- (BOOL)isFileTypeImage:(NSString *)filename {
	return [self.possibleImageExtensions containsObject:filename.lowercaseString.pathExtension];
}

- (BOOL)isMimeTypeImage:(NSString *)mimeType {
	return [self.possibleImageMimeTypes containsObject:mimeType.lowercaseString];
}

- (BOOL)isFileTypeZip:(NSString *)filename {
	return [self.possibleArchivedMimeTypes containsObject:filename.lowercaseString.pathExtension];
}

- (NSString *)mimeTypeForFile:(NSString *)filename {
	return self.mimeToExtensionMap[filename.pathExtension.lowercaseString];
}

- (NSString *)pathExtensionForMimeType:(NSString *)mimeType {
	return self.extensionToMimeMap[mimeType.lowercaseString];
}

@end
