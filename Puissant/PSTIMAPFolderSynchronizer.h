//
//  PSTIMAPFolderSynchronizer.h
//  DotMail
//
//  Created by Robert Widmann on 10/11/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

typedef NS_ENUM(NSUInteger, PSTFolderSynchronizerOptions) {
	PSTFolderSynchronizerOptionNone = 0,
	PSTFolderSynchronizerOptionIDLE = 1,
	PSTFolderSynchronizerOptionSyncPop = 2,
	PSTFolderSynchronizerOptionRefresh,
	PSTFolderSynchronizerOptionPushModifiedMessages,
};

@class PSTIMAPAccountSynchronizer, MCOIMAPFolder, PSTDatabaseController, MCOIMAPSession;

@interface PSTIMAPFolderSynchronizer : NSObject

@property (nonatomic, strong) PSTDatabaseController *database;
@property (nonatomic, strong, readonly) MCOIMAPFolder *folder;
@property (nonatomic, assign, getter = isDraftSynchronizer) BOOL draftSynchronizer;
@property (nonatomic, assign, getter = isTrashSynchronizer) BOOL trashSynchronizer;

/**
 * Initializes a folder synchronizer with the given folder and prepares it for sync.
 */
- (id)initWithSession:(MCOIMAPSession *)session forFolder:(MCOIMAPFolder*)folder;

/**
 * Starts the default sync series and returns a subject that can be subscribed to for changes.  
 * The subject sends next for progress updates and completed when all headers and flags have been 
 * fetched and sync'd, and error when any of the intermediary steps in the sync process fails.  
 * Synchronization fails and returns immediately from errors.
 */
- (RACSignal *)sync;
- (RACSignal *)syncWithOptions:(PSTFolderSynchronizerOptions)options;
- (RACSignal *)idle;

/**
 * Cancels the given synchronizer by allowing it's operation to expire and the internal disposable
 * to expire.
 */
- (void)cancel;

@property (nonatomic, weak) PSTIMAPAccountSynchronizer *parentSynchronizer;

@end
