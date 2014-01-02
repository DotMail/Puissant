//
//  PSTStorageOperation.h
//  DotMail
//
//  Created by Robert Widmann on 10/13/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@class PSTDatabase, PSTDatabaseController, PSTIMAPAccountSynchronizer;
@protocol PSTStorageOperationDelegate;

/**
 * An abstract class that encapsulates a request to the Database files.  This class is meant to
 * serve as a base class for requests, and is freely and highly subclass-able.  Subclasses must
 * override -mainRequest (not -main), and can optionally override -mainFinished.  Operations should
 * typically be sent a -startRequest message immediately after being created, but this is a general
 * guideline and is not enforced by the class.  Operations must be serialized for proper database 
 * resource access.
 */

@interface PSTStorageOperation : NSOperation {
	BOOL _started;
}

/**
 * The delegate for this request object.
 */
@property (nonatomic, weak) id <PSTStorageOperationDelegate> delegate;


/**
 * The database controller for this request object.
 */
@property (nonatomic, strong) PSTDatabaseController *storage;

/**
 * Returns whether or not the request is enqueued on the database queue or the main request queue on
 * it's controller.  Should always be YES for operations that access or commit to the database.
 * Defaults to YES.
 */
@property (nonatomic, assign, getter = doesUseDatabase) BOOL usesDatabase;

/**
 * The database the operation will act upon.  Note: This is a required field.
 */
@property (nonatomic, strong) PSTDatabase *database;

/**
 * Enqueues the operation on the proper queue, then waits for a -main message to be sent.
 */
- (void)startRequest;

/**
 * Cancels the operation and prepares it for deallocation.
 */
- (void)cancel;

/**
 * Performs the receiver’s non-concurrent task. 
 */
- (void)mainRequest;

/**
 * An internal callback for when the reciever has finished executing.
 */
- (void)mainFinished;

@end


@protocol PSTStorageOperationDelegate <NSObject>

- (void)storageOperationDidFinish:(PSTStorageOperation *)op;

@optional
- (void)storageOperationDidUpdateProgress:(PSTStorageOperation *)op;
- (void)storageOperationDidUpdateState:(PSTStorageOperation *)op;

@end