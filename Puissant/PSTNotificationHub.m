//
//  PSTNotificationHub.m
//  Puissant
//
//  Created by Robert Widmann on 1/26/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTNotificationHub.h"
#import <MailCore/mailcore.h>
#import "PSTAccountController.h"
#import "MCOAddress+PSTPrettification.h"
#import "NSApplication+PSTSystemAdditions.h"
//#import <Growl/Growl.h>
#import "MCOIMAPMessage+PSTExtensions.h"
#import "PSTSerializableMessage.h"

@interface PSTNotificationHub ()

@property (nonatomic, strong) NSMutableArray *notificationQueue;

@end

@implementation PSTNotificationHub {
	struct {
		unsigned int notificationScheduled:1;
		unsigned int processingQueue:1;
	} _notificationHubFlags;
}

#pragma mark - Lifecycle

+ (instancetype) defaultNotificationHub {
	PUISSANT_SINGLETON_DECL(PSTNotificationHub);
}

- (id)init {
	self = [super init];
	
	_notificationQueue = [[NSMutableArray alloc] init];
	
	return self;
}

#pragma mark - System Specs

- (BOOL)isNotificationCenterEnabled {
	return [NSApplication dm_runningMountainLionOrLater];
}

- (BOOL)isGrowlInstalled {
	BOOL result = YES;
	if (![NSApplication dm_runningMountainLionOrLater]) {
//		if (![GrowlApplicationBridge isMistEnabled]) {
//			result = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.Growl.GrowlHelperApp"];
//		}
	}
	return result;
}

#pragma mark - Queue Notifications

- (void)queueNotificationForMessage:(PSTSerializableMessage *)message conversationID:(long long)conversationID account:(PSTAccountController *)account {
	NSMutableDictionary *notificationDictionary = [[NSMutableDictionary alloc] init];
	[notificationDictionary setObject:@(message.uid) forKey:PSTMessageKey];
	[notificationDictionary setObject:@(conversationID) forKey:PSTConversationIDKey];
	[notificationDictionary setObject:account forKey:PSTAccountKey];
	
	if (message.from != nil) {
		[notificationDictionary setObject:message.from.dm_prettifiedDisplayString forKey:PSTTitleKey];
	}
	NSString *candidatePreview = [account previewForMessage:message atPath:message.dm_folder.path];
	NSString *messagePreview = @"";
	if (candidatePreview.length < 0xc9) {
		messagePreview = candidatePreview;
	} else {
		messagePreview = [[candidatePreview substringToIndex:0xc8]stringByAppendingString:@"..."];
	}
	if (![self isNotificationCenterEnabled]) {
		return;
	}
	
	NSString *messageSubject = message.subject;
	if (message.subject.length == 0) {
		messageSubject = @"(no subject)";
	}
	NSString *notificationBody = @"";
	if (messageSubject.length) {
		if (messagePreview.length == 0) {
			notificationBody = messageSubject;
		} else {
			notificationBody = [NSString stringWithFormat:@"%@\n%@", messageSubject, messagePreview];
		}
	}
	notificationDictionary[PSTPreviewKey] = notificationBody;
	[self.notificationQueue addObject:notificationDictionary];
	[self _scheduleNotification];
}

- (void)_scheduleNotification {
	if (_notificationHubFlags.notificationScheduled) {
		return;
	}
	else {
		_notificationHubFlags.notificationScheduled = YES;
		[self performSelector:@selector(_processQueueOrCoalesce) withObject:nil afterDelay:0.1];
	}
}

- (void)_processQueueOrCoalesce {
	_notificationHubFlags.notificationScheduled = NO;
	if (self.notificationQueue.count >= 3) {
		[self _showUnified];
	} else {
		[self _processQueue];
	}
}

- (void)_processQueue {
	if (_notificationHubFlags.processingQueue == NO) {
		_notificationHubFlags.processingQueue = YES;
		if (self.notificationQueue.count != 0) {
			do
			{
				[self _showNotification:[self.notificationQueue objectAtIndex:0]];
				[self.notificationQueue removeObjectAtIndex:0];
			}
			while (self.notificationQueue.count != 0);
		}
		_notificationHubFlags.processingQueue = NO;
		[self _scheduleNotification];
	}
}

- (void)_showUnified {
	NSMutableDictionary *newNotification = [[NSMutableDictionary alloc] init];
	newNotification[PSTTitleKey] = [self.notificationQueue[0][PSTAccountKey] addressValueWithName:NO].mailbox;
	[newNotification setObject:[NSString stringWithFormat:@"%lu new messages", (unsigned long)self.notificationQueue.count] forKey:PSTPreviewKey];
	[self _showNotification:newNotification];
	
	[self.notificationQueue removeAllObjects];
}

- (void)_showNotification:(NSMutableDictionary *)notification {
	if ([self isNotificationCenterEnabled]) {
		NSUserNotification *newNotification = [[NSUserNotification alloc] init];
		[newNotification setTitle:notification[PSTTitleKey]];
		[newNotification setInformativeText:notification[PSTPreviewKey]];
		[newNotification setDeliveryDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:newNotification];
	}
}

@end