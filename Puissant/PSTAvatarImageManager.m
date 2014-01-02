//
//  PSTAvatarImageManager.m
//  Puissant
//
//  Created by Robert Widmann on 4/12/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTAvatarImageManager.h"
#import "PSTImageMapTable.h"
#import "PSTCache.h"
#import "PSTAvatarFetchOperation.h"

@interface PSTAvatarImageManager ()

@property (nonatomic, strong) PSTCache *imageCache;
@property (nonatomic, strong) PSTCache *expiredImageCache;
@property (nonatomic, strong) NSOperationQueue *requestQueue;
@property (nonatomic, strong) NSMutableSet *pendingEmails;
@property (nonatomic, strong) NSMutableArray *activeGravatarRequests;
@property (nonatomic, strong) NSMutableArray *activeFacebookRequests;

@end

@implementation PSTAvatarImageManager

+ (instancetype)defaultManager {
	PUISSANT_SINGLETON_DECL(PSTAvatarImageManager);
}

- (id)init {
	self = [super init];
	
	[PSTImageMapTable defaultMapTable];
	
	_imageCache = [[PSTCache alloc]init];
	[_imageCache setMaxSize:0x3e8];
	_expiredImageCache= [[PSTCache alloc]init];
	_requestQueue = [[NSOperationQueue alloc]init];
	_requestQueue.name = @"com.CodaFi.PSTAvatarImageManager.RequestQueue";
	_pendingEmails = [[NSMutableSet alloc]init];
	_activeGravatarRequests = [[NSMutableArray alloc]init];
	_activeFacebookRequests = [[NSMutableArray alloc]init];
	[self performSelector:@selector(restoreImageCache) withObject:nil afterDelay:0];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_abLoaded) name:@"PSTAddressManagerABLoaded" object:nil];
	
	return self;
}

- (void)restoreImageCache {
	NSDictionary *imageCache = [[NSDictionary alloc]initWithContentsOfFile:fileName()];
	if (imageCache) {
		for (NSString *email in imageCache[@"Emails"]) {
			[self avatarForEmail:email];
		}
	}
}

- (NSImage *)avatarForEmail:(NSString*)email {
	if (email == nil) return defaultImage();
	id obj = self.imageCache[email];
	if ((obj && [obj isKindOfClass:NSNumber.class]) || !obj) {
		[self _loadImageForEmail:email];
		NSImage *expiredImage = [self.expiredImageCache objectForKey:email];
		if (expiredImage) {
			return expiredImage;
		}
		return defaultImage();
	}
	if ([obj isKindOfClass:NSData.class]) {
		return [[NSImage alloc]initWithData:obj];
	}
	return obj;
}

- (void)_loadImageForEmail:(NSString*)email {
	if ([self.pendingEmails containsObject:email]) {
		return;
	}
	[self.requestQueue addOperation:[PSTAvatarFetchOperation avatarFetchOperationForEmail:email completion:^(PSTAvatarFetchOperation *op) {
		[NSNotificationCenter.defaultCenter postNotificationName:PSTAvatarImageManagerDidUpdateNotification object:nil];
		[self.pendingEmails removeObject:op.email];
		if (!op.isCancelled) {
			if (op.image != nil) {
				[self.imageCache setObject:op.image forKey:op.email];
				return;
			}
			[self.imageCache setObject:defaultImage() forKey:op.email];
			return;
		}
		[self.imageCache removeObjectForKey:op.email];
	}]];
}

- (void)_abLoaded {
	[self _resetCache];
}

- (void)_resetCache {
	for (NSOperation *op in self.requestQueue.operations) {
		[op cancel];
	}
	for (NSString *key in self.imageCache.allKeys) {
		NSObject *obj = self.imageCache[key];
		if ([obj isKindOfClass:NSImage.class]) {
			self.expiredImageCache[key] = obj;
		}
	}
	[self.pendingEmails removeAllObjects];
	[self.imageCache removeAllObjects];
}

- (oneway void)close {
	NSMutableDictionary *plist = @{}.mutableCopy;
	NSMutableDictionary *cacheMap = @{}.mutableCopy;\
	__block int idx = 0;
	[self.imageCache enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if (idx >= 100) {
			*stop = YES;
		}
		[cacheMap setObject:obj forKey:key];
		idx++;
	}];
	[plist setObject:cacheMap forKey:@"Emails"];
	[plist writeToFile:fileName() atomically:YES];
}

static NSString *fileName() {
	return [@"~/Library/Application Support/DotMail/AvatarsCache.plist" stringByExpandingTildeInPath];
}

static NSImage *defaultImage() {
	return [NSImage imageNamed:@"AvatarDefault.png"];
}

@end
