//
//  NSString+PSTFilenames.m
//  Puissant
//
//  Created by Robert Widmann on 12/2/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "NSString+PSTFilenames.h"
#import "PSTMimeManager.h"
#import <MailCore/mailcore.h>

@implementation NSString (PSTFilenames)

+(NSString*)dmAttachmentFilenameWithBasePath:(NSString*)basePath filename:(NSString*)filename mimeType:(NSString*)mimeType {
	return [NSString dmAttachmentFilenameWithBasePath:basePath filename:filename mimeType:mimeType defaultName:nil withExtension:nil];
}

+(NSString*)dmAttachmentFilenameWithBasePath:(NSString*)basePath filename:(NSString*)filename mimeType:(NSString*)mimeType defaultName:(NSString*)defaultName withExtension:(NSString*)extension {
	NSString *result = nil;
	NSString *ext = nil;
	NSString *filenameWithExtension = nil;
	
	if (extension == nil) {
		 ext= [[PSTMimeManager sharedManager]pathExtensionForMimeType:mimeType];
		if (ext != nil) {
			filenameWithExtension = [filename stringByAppendingPathExtension:ext];
		} else {
			filenameWithExtension = @"";
		}
	}
	result = [[filenameWithExtension stringByReplacingOccurrencesOfString:@"/" withString:@":"]lastPathComponent];
	return [basePath stringByAppendingPathComponent:result];
}

@end
