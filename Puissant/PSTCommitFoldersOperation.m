//
//  PSTCommitFoldersOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/24/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTCommitFoldersOperation.h"
#import "PSTDatabase.h"

@implementation PSTCommitFoldersOperation {
	void(^_callback)(void);
}

- (void)start:(void(^)(void))callback {
	_callback = callback;
	[super startRequest];
}

- (void)mainRequest {
	if (!self.isCancelled) {
		[self.database beginTransaction];
		for (NSString *folderPath in self.folderPaths) {
			[self.database addFolder:folderPath];
		}
		[self.database commit];
	}
}

- (void)mainFinished {
	if (_callback) {
		_callback();
	}
}

@end
