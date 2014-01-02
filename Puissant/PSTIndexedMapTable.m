//
//  PSTIndexedCache.m
//  Puissant
//
//  Created by Robert Widmann on 11/14/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTIndexedMapTable.h"
#import "PSTLevelDBCache.h"
#import "NSData+PSTCompression.h"

@interface PSTIndexedMapTable ()

@property (nonatomic, copy) NSString *prefix;

@end

@implementation PSTIndexedMapTable

- (id)initWithPrefix:(NSString *)prefix {
	self = [super init];
	
	_prefix = prefix;
	
	return self;
}

- (void)setData:(NSData *)data forIndex:(NSUInteger)index {
	[self.hashFile setData:data forKey:[NSString stringWithFormat:@"%@%lu", self.prefix, (unsigned long)index]];
}

- (NSData *)dataForIndex:(NSUInteger)idx {
	return [self.hashFile dataForKey:[NSString stringWithFormat:@"%@%lu", self.prefix, idx]];
}

- (void)removeDataForIndex:(NSUInteger)index {
	[self.hashFile removeDataForKey:[NSString stringWithFormat:@"%@%lu", self.prefix, (unsigned long)index]];
}

@end

@implementation PSTIndexedMapTable (PSTExtendedIndexedMapTable)

- (BOOL)hasDataForIndex:(NSUInteger)idx {
	return [self.hashFile hasDataForKey:[NSString stringWithFormat:@"%@%lu", self.prefix, (unsigned long)index]];
}

@end

@implementation PSTIndexedMapTable (PSTSubscripting)

- (id)objectAtIndexedSubscript:(NSUInteger)key {
	return [self dataForIndex:key];
}

- (void)setObject:(NSData*)obj forKeyedSubscript:(NSUInteger)key {
	[self setData:obj forIndex:key];
}

@end
