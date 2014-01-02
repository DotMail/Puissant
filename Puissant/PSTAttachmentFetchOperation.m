//
//  PSTAttachmentFetchOperation.m
//  Puissant
//
//  Created by Robert Widmann on 3/22/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTAttachmentFetchOperation.h"
#import "PSTDatabase.h"

@implementation PSTAttachmentFetchOperation {
	NSArray *_attachments;
	void(^_callback)(NSArray *);
}

- (void)start:(void(^)(NSArray *))callback {
	_callback = callback;
	[super startRequest];
}

- (void)mainRequest {
	switch (self.mode) {
		case PSTAttachmentFetchModeAll:
			_attachments = [self.database attachmentsNotInTrashFolder:self.trashFolder orAllMailFolder:self.allMailfolder];
			break;
		case PSTAttachmentFetchModeForFolder:
			_attachments = [self.database attachmentsInFolder:self.selectedFolder];
			break;
		default:
			break;
	}
}

- (void)mainFinished {
	if (_callback) {
		_callback(_attachments);
	}
}

@end
