//
//  PSTHashTableFile.h
//  Puissant
//
//  Created by Robert Widmann on 11/14/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A mutable collection class modeled after NSDictionary that interfaces with a shared Tokyo Cabinet 
 * cache and flushes it's data into it.  Keys are automatically prepended with a required prefix.
 */

@class PSTLevelDBCache;

@interface PSTLevelDBMapTable : NSObject

/// Default Initializer
- (id)initWithCache:(PSTLevelDBCache *)cache dataPrefix:(NSString *)prefix;

/**
 * Adds a given key-value pair to the map table.
 */
- (void)setData:(NSData *)data forKey:(NSString *)key;

/**
 * Returns a the value associated with a given key.
 */
- (NSData *)dataForKey:(NSString *)key;

/**
 * Removes a given key and its associated value from the map table.
 */
- (void)removeDataForKey:(NSString *)key;

@property (nonatomic, strong, readonly) PSTLevelDBCache *hashFile;

@end

@interface PSTLevelDBMapTable (PSTExtendedMapTable)

/**
 * Returns whether or not the internal Tokyo Cabinet cache contains a value for 
 * a given key.
 */
- (BOOL)hasDataForKey:(NSString *)key;

/**
 * Submits an observation block for a given key.  When data for that key is set 
 * or updated, the map table will execute the provided block.
 */
- (void)addObserverForUID:(NSString *)key withBlock:(void(^)(NSData *))block;

/**
 * Removes all observers for a given UID.
 */
- (void)removeObserverForUID:(NSString *)obj;

@end

/**
 * Adds support for keyed subscripting to the cache.
 */
@interface PSTLevelDBMapTable (PSTSubscripting)

- (id)objectForKeyedSubscript:(NSString*)key;
- (void)setObject:(NSData*)obj forKeyedSubscript:(NSString*)key;

@end
