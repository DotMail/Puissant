//
//  PSTAttachmentPrototype.m
//  Puissant
//
//  Created by Robert Widmann on 3/22/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTAttachmentCache.h"
#import "PSTMimeManager.h"
#import <Quartz/Quartz.h>
#import <MailCore/mailcore.h>

@implementation PSTAttachmentCache

- (BOOL)isImage {
	return [PSTMimeManager.sharedManager isFileTypeImage:self.filename];
}

- (BOOL)isArchive {
	return [PSTMimeManager.sharedManager isFileTypeZip:self.filename];
}

@end

@implementation PSTAttachmentCache (QLPreviewItem)

- (NSURL *)previewItemURL {
	return [NSURL fileURLWithPath:self.filepath];
}

- (NSString *)previewItemTitle {
	return self.filename;
}

@end