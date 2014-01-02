//
//  PSTActivityManager.m
//  DotMail
//
//  Created by Robert Widmann on 11/18/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTConstants.h"
#import "PSTActivityManager.h"
#import "PSTActivity.h"

@interface PSTActivityManager ()

@property (nonatomic, strong) NSMutableArray *activities;

@end

@implementation PSTActivityManager

#pragma mark - Initialization

+ (PSTActivityManager *)sharedManager {
	PUISSANT_SINGLETON_DECL(PSTActivityManager);
}

#pragma mark - Lifecycle

- (id)init {
	self = [super init];
	
	self.activities = @[].mutableCopy;

	return self;
}

- (void)dealloc {
	for (PSTActivity *activity in self.activities) {
		[self removeActivity:activity];
	}
}

#pragma mark - Activity Management

- (void)registerActivity:(PSTActivity *)activity {
	[self performSelectorOnMainThread:@selector(_registerActivity:) withObject:activity waitUntilDone:NO];
}

- (void)_registerActivity:(PSTActivity *)activity {
	NSAssert(activity != nil, @"The caller attempted to push a nil activity onto the stack %@ %p.", self, self);
	
	//break early
	if ([self.activities containsObject:activity]) {
		return;
	}
	PSTPropogateValueForKey(self.activities, {
		[self.activities addObject:activity];
	});
	[self.activities addObject:activity];
	[self broadcastUpdate];	//Notify observers
}

- (void)removeActivity:(PSTActivity *)activity {
	[self performSelectorOnMainThread:@selector(_removeActivity:) withObject:activity waitUntilDone:NO];
}

- (void)_removeActivity:(PSTActivity *)activity {
	//break early
	if (![self.activities containsObject:activity]) {
		return;
	}
	PSTPropogateValueForKey(self.activities, {
		[self.activities removeObject:activity];
	});
	[self broadcastUpdate];	//Notify observers
}

- (void)clearAllActivitiesFromAccount:(NSString *)email {
	[self.activities removeObjectsAtIndexes:[self.activities indexesOfObjectsPassingTest:^BOOL(PSTActivity *obj, NSUInteger idx, BOOL *stop) {
		return [obj.email isEqualToString:email];
	}]];
}

- (void)clearAllActivities {
	for (PSTActivity *activity in self.activities) {
		[self removeActivity:activity];
	}
}

- (void)broadcastUpdate {
	[NSNotificationCenter.defaultCenter postNotificationName:PSTActivityManagerDidUpdateNotification object:self];
}

#pragma mark - NSObject

- (NSString *)description {
	NSMutableString *result = [NSMutableString string];
	[result appendString:@"-- PSTActivities Currently Scheduled --\n"];
	for (PSTActivity *activity in self.activities) {
		[result appendString:activity.description];
		[result appendString:@"\n"];
	}
	[result appendString:@"-- PSTActivities End --"];
	return [result copy];
}

@end