//
//  PSTStorageOperation.m
//  DotMail
//
//  Created by Robert Widmann on 10/13/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTStorageOperation.h"
#import "PSTDatabaseController.h"
#import "PSTDatabase.h"

@interface PSTStorageOperation ()
@property (nonatomic, strong) NSIndexSet *modifiedConversations;
@property (nonatomic, strong) NSIndexSet *deletedConversations;
@end

@implementation PSTStorageOperation

- (id)init {
	self = [super init];
	self.usesDatabase = YES;
	return self;
}

- (void)setDatabase:(PSTDatabase *)database {
	_database = database;
}

- (void)startRequest {
	if (self.usesDatabase) {
		[_storage queueDatabaseOperation:self];

	} else {
		[_storage queueOperation:self];
	}
}

- (void)cancel {
	[super cancel];
}

- (void)main {
	[self mainRequest];
	[self performSelectorOnMainThread:@selector(_finished) withObject:nil waitUntilDone:NO];
}

- (void)mainRequest
{
}

- (void)mainFinished
{
}

- (void)_finished {
	if (self.modifiedConversations.count != 0) {
		NSMutableDictionary *userInfo = [[NSMutableDictionary alloc]init];
		[userInfo setObject:self.modifiedConversations forKey:@"ModifiedConversations"];
		[userInfo setObject:self.deletedConversations forKey:@"DeletedConversations"];
		[NSNotificationCenter.defaultCenter postNotificationName:PSTStorageGotModifiedConversationNotification object:self.storage userInfo:userInfo];
	}
	
	[self mainFinished];
	
	[[self delegate] storageOperationDidFinish:self];
}


@end
