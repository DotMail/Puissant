//
//  PSTAddAttachmentOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/21/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTAddAttachmentOperation.h"
#import "PSTDatabase.h"

@implementation PSTAddAttachmentOperation

- (void)mainRequest {
	[self.database addAttachment:self.message inFolder:self.path partID:self.partID filename:self.filename data:self.data mimeType:self.mimeType];
}

@end
