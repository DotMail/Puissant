//
//  PSTFlagsUpdateBatcher.m
//  Puissant
//
//  Created by Robert Widmann on 11/20/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTFlagsUpdateBatcher.h"
#import "PSTStorageOperation.h"
#import "PSTDatabaseController+Operations.h"
#import "PSTLoadCachedFlagsOperation.h"
#import "PSTUpdateMessagesFlagsFromServerOperation.h"
#import "PSTSaveCachedFlagsOperation.h"

@interface PSTFlagsUpdateBatcher () <PSTStorageOperationDelegate>

@property (nonatomic, strong) PSTLoadCachedFlagsOperation *loadOperation;
@property (nonatomic, strong) PSTStorageOperation *importOperation;
@property (nonatomic, strong) PSTUpdateMessagesFlagsFromServerOperation *storeFlagsOperation;
@property (nonatomic, strong) PSTSaveCachedFlagsOperation *saveOperation;
@property (nonatomic, copy) void(^completionBlock)();

@end

@implementation PSTFlagsUpdateBatcher

- (void)start {
	[self _loadDiff];
}

- (void)startRequestWithCompletion:(void(^)())completionBlock {
	[self _loadDiff];
	self.completionBlock = completionBlock;
}

- (void)_loadDiff {
	self.loadOperation = [self.storage diffCacheFlagsOperationForFolder:self.folder messages:self.messages];
	[self.loadOperation setDelegate:self];
	[self.loadOperation startRequest];
}

- (void)_loadDiffDone {
	self.messagesFlags = [self.loadOperation messagesFlags];
	if (self.messagesFlags.count != 0) {
		self.hadChanges = YES;
	}
	self.loadOperation = nil;
	[self _startStoreFlags];
}

- (void)_importOldFlagsCache {
	self.importOperation = [self.storage importCacheFlagsOperationForFolder:self.folder];
	[self.importOperation setDelegate:self];
	[self.importOperation startRequest];
}

- (void)_importOldFlagsCacheDone {
	self.importOperation = nil;
	self.messagesFlags = [self.messages mutableCopy];
	[self _startStoreFlags];
}

- (void)_startStoreFlags {
	PSTLog(@"fetch flags for %lu messages", self.messages.count);
	[self _requestFlagsStoreNextFlags];
}

- (void)_requestFlagsStoreNextFlags {
	if (self.messagesFlags.count == 0) {
		[self _requestFlagsAllStorageDone];
	}
	else {
		self.storeFlagsOperation = [self.storage updateMessagesFlagsFromServerOperation:self.messagesFlags atPath:self.folder.path];
		[self.storeFlagsOperation setDelegate:self];
		[self.storeFlagsOperation startRequest];
	}
}

- (void)_requestFlagsStorageDone {
	if ([self.storeFlagsOperation hasDeletedFlags]) {
		self.hadDeletedFlags = YES;
	}
	if ([self.storeFlagsOperation hadChanges]) {
		self.hadChanges = YES;
	}
	self.storeFlagsOperation = nil;
	[self.messagesFlags removeAllObjects];
	[self _requestFlagsStoreNextFlags];
}

- (void)_requestFlagsAllStorageDone {
	self.messagesFlags = nil;
	[self _saveCache];
}

- (void)_saveCache {
	if (self.hadChanges == NO) {
		[self _saveCacheOperationDone];
	}
	else {
		self.saveOperation = [self.storage saveCacheFlagsOperationForFolder:self.folder messages:self.messages];
		[self.saveOperation setDelegate:self];
		[self.saveOperation startRequest];
	}
}

- (void)_saveCacheOperationDone {
	self.saveOperation = nil;
	[self _done];
}

- (void)_done {
	if (self.completionBlock != nil) {
		self.completionBlock();
	}
	[self _startCleanup];
}

- (void)_startCleanup {
	self.messages = nil;
	self.messagesFlags = nil;
}


- (void)storageOperationDidFinish:(PSTStorageOperation *)op {
	if (self.storeFlagsOperation != op) {
		if (self.saveOperation != op) {
			if (self.loadOperation != op) {
				if (self.importOperation != op) {
					//WTF?
				}
				else {
					[self _importOldFlagsCacheDone];
				}
			}
			else {
				[self _loadDiffDone];
			}
		}
		else {
			[self _saveCacheOperationDone];
		}
	}
	else {
		[self _requestFlagsStorageDone];
	}
}

- (void)cancel {
	self.messagesFlags = nil;
}

@end
