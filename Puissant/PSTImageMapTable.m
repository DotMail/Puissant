//
//  PSTAvatarMapTable.m
//  Puissant
//
//  Created by Robert Widmann on 4/12/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTImageMapTable.h"
#import "PSTLevelDBCache.h"

@implementation PSTImageMapTable {
	PSTLevelDBCache *_cache;
}

+ (instancetype) defaultMapTable {
	static PSTImageMapTable *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		PSTLevelDBCache *cache = [[PSTLevelDBCache alloc]initWithPath:PSTCacheDirectory()];
		sharedInstance = [[self alloc] initWithCache:cache dataPrefix:@"img."];
	});
	return sharedInstance;
}

- (id)initWithCache:(PSTLevelDBCache *)cache dataPrefix:(NSString *)prefix {
	self = [super initWithCache:cache dataPrefix:prefix];
	
	_cache = cache;
	if (![self.hashFile open]) {
		[self.hashFile close];
	}
	return self;
}

- (PSTLevelDBCache *)hashFile {
	return _cache;
}

- (void)setImage:(NSImage *)image forEmail:(NSString *)key {
	[self setImage:image forKey:key.lowercaseString];
}

- (NSImage *)imageForEmail:(NSString *)key {
	return [self imageForKey:key.lowercaseString];
}

- (void)setImage:(NSImage *)image forKey:(NSString *)key {
	@synchronized(self) {
		[self setData:[NSKeyedArchiver archivedDataWithRootObject:@{ @"date" : NSDate.date, @"image" : image.TIFFRepresentation }] forKey:key];
	}
}

- (NSImage *)imageForKey:(NSString *)key {
	NSData *archivedImageData = nil;
	@synchronized(self) {
		archivedImageData = [self dataForKey:key];
	}
	
	NSImage *retVal = nil;
	if (archivedImageData.length != 0) {
		NSDictionary *data = [NSKeyedUnarchiver unarchiveObjectWithData:archivedImageData];
		retVal = data[@"image"];
//		NSDate *date = data[@"date"];
	}
	
	return retVal;
}

static NSString *PSTCacheDirectory() {
	return [@"~/Library/Application Support/DotMail/Avatars.ldb" stringByExpandingTildeInPath];
}

@end
