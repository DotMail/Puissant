//
//  PSTLaunchServicesManager.m
//  Puissant
//
//  Created by Robert Widmann on 7/12/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTLaunchServicesManager.h"

// This constant is undefined in versions of AppKit lower than 10.6
#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_6
static NSString * const kLSSharedFileListLoginItemHidden = @"com.apple.loginitem.HideOnLaunch";
#endif

@interface PSTLaunchServicesManager ()
@property (nonatomic, copy) NSString *bundlePath;
@property (nonatomic, copy) NSString *bundleID;
@end

@implementation PSTLaunchServicesManager

+ (instancetype)defaultManager {
	PUISSANT_SINGLETON_DECL(PSTLaunchServicesManager);
}

- (id)init {
	self = [super init];
	
	_bundlePath = NSBundle.mainBundle.bundlePath;
	_bundleID = NSBundle.mainBundle.bundleIdentifier;

	return self;
}

- (BOOL)toggleCurrentApplicationAsDefaultHandlerForEmail {
	if (self.isCurrentApplicationRegisteredAsDefaultHandlerForEmail) {
		return [self revokeCurrentApplicationAsDefaultHandlerForEmail];
	}
	return [self assertCurrentApplicationAsDefaultHandlerForEmail];
}

- (BOOL)revokeCurrentApplicationAsDefaultHandlerForEmail {
	if (!self.isCurrentApplicationRegisteredAsDefaultHandlerForEmail) return NO;
	
	BOOL result = YES;
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"mailto", (__bridge CFStringRef)@"com.apple.Mail");
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"message", (__bridge CFStringRef)@"com.apple.Mail");
	CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)@"eml", kUTTypeData);
	OSStatus emlRoleSuccessful = LSSetDefaultRoleHandlerForContentType(contentType, kLSRolesAll, (__bridge CFStringRef)@"com.apple.Mail");
	if (emlRoleSuccessful != noErr) result = NO;
	CFRelease(contentType);
	return result;
}

- (BOOL)assertCurrentApplicationAsDefaultHandlerForEmail {
	if (self.isCurrentApplicationRegisteredAsDefaultHandlerForEmail) return NO;

	BOOL result = YES;
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"mailto", (__bridge CFStringRef)_bundleID);
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"message", (__bridge CFStringRef)_bundleID);
	CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)@"eml", kUTTypeData);
	OSStatus emlRoleSuccessful = LSSetDefaultRoleHandlerForContentType(contentType, kLSRolesAll, (__bridge CFStringRef)_bundleID);
	if (emlRoleSuccessful != noErr) result = NO;
	CFRelease(contentType);
	return result;
}

- (BOOL)isCurrentApplicationRegisteredAsDefaultHandlerForEmail {
	BOOL result = NO;
	CFStringRef currentDefaultHandler = LSCopyDefaultHandlerForURLScheme((CFStringRef)@"mailto");
	if ([(__bridge NSString *)currentDefaultHandler isEqualToString:_bundleID]) {
		result = YES;
		CFStringRef currentDefaultMessageHandler = LSCopyDefaultHandlerForURLScheme((CFStringRef)@"message");
		if (![(__bridge NSString *)currentDefaultMessageHandler isEqualToString:_bundleID]) {
			result = [self assertCurrentApplicationAsDefaultHandlerForEmail];
		}
		CFRelease(currentDefaultMessageHandler);
	}
	CFRelease(currentDefaultHandler);
	
	return result;
}

- (void)insertCurrentApplicationInStartupItems:(BOOL)hideAtLaunch {
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:_bundlePath];
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	if (loginItems) {
		NSDictionary *propertiesToSet = @{ (__bridge id)kLSSharedFileListLoginItemHidden : @(hideAtLaunch) };
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, url, (__bridge CFDictionaryRef)propertiesToSet, NULL);
		if (item){
			CFRelease(item);
		}
	}
	
	CFRelease(loginItems);
}

- (void)removeCurrentApplicationFromStartupItems {
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:_bundlePath];
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	
	if (loginItems) {
		UInt32 seedValue;
		NSArray  *loginItemsArray = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
		for(int i = 0; i< [loginItemsArray count]; i++){
			LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)[loginItemsArray objectAtIndex:i];
			if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
				NSString * urlPath = [(__bridge NSURL *)url path];
				if ([urlPath compare:_bundlePath] == NSOrderedSame){
					LSSharedFileListItemRemove(loginItems,itemRef);
				}
			}
		}
	}
}

@end
