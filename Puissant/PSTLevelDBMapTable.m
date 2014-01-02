//
//  PSTHashTableFile.m
//  Puissant
//
//  Created by Robert Widmann on 11/14/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTLevelDBMapTable.h"
#import "NSData+PSTCompression.h"
#import "PSTLevelDBCache.h"

typedef void (^PSTCacheCallbackBlock)(NSData *);

@interface PSTLevelDBMapTable ()

@property (nonatomic, assign) NSUInteger transactionCount;
@property (nonatomic, copy) NSString *prefix;
@property (nonatomic, strong) NSMutableDictionary *callbackTable;

@end

@implementation PSTLevelDBMapTable

- (id)initWithCache:(PSTLevelDBCache *)cache dataPrefix:(NSString *)prefix {
	self = [super init];
	
	_prefix = prefix;
	_hashFile = cache;
	_callbackTable = [NSMutableDictionary dictionary];
	
	return self;
}

- (void)setData:(NSData *)data forKey:(NSString *)key {	
	NSString *prefixedKey = [self.prefix stringByAppendingString:key];
	[self.hashFile setData:data forKey:prefixedKey];
	
	void(^callback)(NSData *) = [self.callbackTable objectForKey:key];
	if (callback != nil) {
		callback(data);
	}
}

- (NSData *)dataForKey:(NSString *)key {
	return [self.hashFile dataForKey:[self.prefix stringByAppendingString:key]];
}

- (void)removeDataForKey:(NSString *)key {
	[self.hashFile removeDataForKey:[self.prefix stringByAppendingString:key]];
}

@end


@implementation PSTLevelDBMapTable (PSTExtendedMapTable)

- (BOOL)hasDataForKey:(NSString *)key {
	return [self.hashFile hasDataForKey:[self.prefix stringByAppendingString:key]];
}

- (void)addObserverForUID:(NSString *)key withBlock:(void(^)(NSData *))block {
	[self.callbackTable setObject:[block copy] forKey:key];
}

- (void)removeObserverForUID:(NSString *)UID {
	PSTCacheCallbackBlock block = [self.callbackTable objectForKey:UID];
	[self.callbackTable removeObjectForKey:UID];
	block = nil;
}

@end

@implementation PSTLevelDBMapTable (PSTSubscripting)

- (id)objectForKeyedSubscript:(NSString *)key {
	return [self dataForKey:key];
}

- (void)setObject:(NSData *)obj forKeyedSubscript:(NSString*)key {
	[self setData:obj forKey:key];
}

@end
