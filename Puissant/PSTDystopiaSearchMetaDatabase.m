//
//  PSTDystopiaSearchMetaDatabase.m
//  Puissant
//
//  Created by Robert Widmann on 3/23/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTDystopiaSearchMetaDatabase.h"
#import "PSTLevelDBCache.h"
#import "NSData+PSTCompression.h"
#import <pthread.h>

pthread_rwlock_t rwlock = PTHREAD_RWLOCK_INITIALIZER;

@interface PSTDystopiaSearchMetaDatabase ()

@property (nonatomic, copy) NSString *path;

@end

@implementation PSTDystopiaSearchMetaDatabase

- (id)initWithPath:(NSString *)path {
	self = [super init];
		
	return self;
}

- (void)setMetaData:(NSString*)data forIndex:(NSUInteger)index {
	[self.hashFile setData:[NSData dmArchivedData:data] forKey:[NSString stringWithFormat:@"%@%lu", self.prefix, (unsigned long)index]];
}

- (NSData *)metaDataForIndex:(NSUInteger)idx {
	return [[self.hashFile dataForKey:[NSString stringWithFormat:@"%@%lu", self.prefix, (unsigned long)index]]dataByStandardUnarchiving];
}

- (void)removeMetaDataForIndex:(NSUInteger)index {
	[self.hashFile removeDataForKey:[NSString stringWithFormat:@"%@%lu", self.prefix, (unsigned long)index]];
}

@end

@implementation PSTDystopiaSearchMetaDatabase (PSTExtendedSearchMetaDatabase)

- (BOOL)hasMetaDataForIndex:(NSUInteger)idx {
	return [self.hashFile hasDataForKey:[NSString stringWithFormat:@"%@%lu", self.prefix, (unsigned long)index]];
}

@end

@implementation PSTDystopiaSearchMetaDatabase (PSTSubscripting)

- (id)objectAtIndexedSubscript:(NSUInteger)key {
	return [self metaDataForIndex:key];
}

- (void)setObject:(NSString*)obj forKeyedSubscript:(NSUInteger)key {
	[self setMetaData:obj forIndex:key];
}

@end
