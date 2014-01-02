//
//  PSTLRUCache.m
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTCache.h"

@interface PSTCache ()

@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, strong) NSMutableDictionary *cacheMap;
@property (nonatomic, strong) NSMutableDictionary *indices;
@property (nonatomic, assign) NSInteger transactionCounter;

@end

@implementation PSTCache

- (id)init {
	self = [super init];
	self.cacheMap = [NSMutableDictionary dictionary];
	self.indices = [NSMutableDictionary dictionary];
	self.maxSize = 100;
	return self;
}

- (id)objectForKey:(id)aKey {
	id result = [self.cacheMap objectForKey:aKey];
	if (result != nil) {
		[self.indices setObject:@(self.count) forKey:aKey];
		if (self.count >= self.maxSize) {
			[self _pruneCacheMap];
		}
	}
	return result;
}

- (void)setObject:(id)object forKey:(id)aKey {
	self.count++;
	[self.cacheMap setObject:object forKey:aKey];
	[self.indices setObject:@(self.count) forKey:aKey];
	if (self.count != self.maxSize) return;
	
	[self _pruneCacheMap];
}

- (void)removeObjectForKey:(id)aKey {
	self.count--;
	[self.cacheMap removeObjectForKey:aKey];
	[self.indices removeObjectForKey:aKey];
}

- (void)removeAllObjects {
	[self.cacheMap removeAllObjects];
	[self.indices removeAllObjects];
}

- (void)beginTransaction {
	self.transactionCounter += 1;
}

- (void)endTransaction {
	self.transactionCounter -= 1;
	if (self.transactionCounter != 0) {
		return;
	}
	[self _pruneCacheMap];
}

- (void)_pruneCacheMap {
	if (self.transactionCounter == 0) {
		if (self.cacheMap.count >= self.maxSize) {
			NSArray *sortedStorage = [self.cacheMap.allKeys sortedArrayUsingFunction:compare context:(__bridge void *)(self)];
			for (NSUInteger i = self.count; i > self.maxSize; i--) {
				[self.cacheMap removeObjectForKey:[sortedStorage objectAtIndex:i - 1]];
			}
			self.count = self.cacheMap.count;
		}
	}
}

- (NSArray *)allKeys {
	return self.cacheMap.allKeys;
}

- (NSArray *)allKeysToLimit:(NSUInteger)lim {
	NSArray *retVal = [self.cacheMap.allKeys sortedArrayUsingFunction:compare context:(__bridge void *)(self)];
	if (retVal.count < lim) {
		return retVal;
	}
	return [retVal subarrayWithRange:NSMakeRange(0, lim)];
}

- (NSArray *)allObjects {
	return self.cacheMap.objectEnumerator.allObjects;
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block {
	[self.cacheMap enumerateKeysAndObjectsUsingBlock:block];
}

- (void)enumerateKeysAndObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id key, id obj, BOOL *stop))block {
	[self.cacheMap enumerateKeysAndObjectsWithOptions:opts usingBlock:block];
}

#pragma mark - Compare Function

static NSInteger compare(id num1, id num2, void *context) {
	return [[((__bridge PSTCache *)context).indices objectForKey:num1] compare:[((__bridge PSTCache *)context).indices objectForKey:num2]];
}

@end

@implementation PSTCache (PSTSubscripting)

- (id)objectForKeyedSubscript:(id)key {
	return [self objectForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
	return [self setObject:obj forKey:key];
}

@end
