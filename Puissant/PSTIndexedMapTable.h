//
//  PSTIndexedCache.h
//  Puissant
//
//  Created by Robert Widmann on 11/14/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A mutable collection class modeled after NSDictionary that interfaces with a shared Tokyo Cabinet
 * cache and flushes it's data into it.  Keys, in this kind of hash map, are in fact index numbers, 
 * which makes this cache effective for operations involving unique identifiers.
 */

@class PSTLevelDBCache;

@interface PSTIndexedMapTable : NSObject

/// Default initializer
- (id)initWithPrefix:(NSString *)prefix;

/**
 * Adds a given index-value pair to the map table.
 */
- (void)setData:(NSData *)data forIndex:(NSUInteger)index;

/**
 * Returns a the value associated with a given index.
 */
- (NSData *)dataForIndex:(NSUInteger)idx;

/**
 * Removes a given index and its associated value from the map table.
 */
- (void)removeDataForIndex:(NSUInteger)index;

@property (nonatomic, strong) PSTLevelDBCache *hashFile;

@end

@interface PSTIndexedMapTable (PSTExtendedIndexedMapTable)

/**
 * Returns whether or not the internal Tokyo Cabinet cache contains a value for a given index.
 */
- (BOOL)hasDataForIndex:(NSUInteger)idx;

@end

/**
 * Adds support for keyed subscripting to the cache.
 */
@interface PSTIndexedMapTable (PSTSubscripting)

- (id)objectAtIndexedSubscript:(NSUInteger)key;
- (void)setObject:(NSData*)obj forKeyedSubscript:(NSUInteger)key;

@end