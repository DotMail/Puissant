//
//  PSTTCHashFile.h
//  Puissant
//
//  Created by Robert Widmann on 11/14/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#include <leveldb/db.h>
#include <leveldb/slice.h>
#include <leveldb/options.h>
#include <leveldb/comparator.h>
#include <leveldb/write_batch.h>
#endif

/**
 * A mutable cache representing a LevelDB database with convenience methods for interacting 
 * with the database.  The class is modeled after NSDictionary, except that keys are required to be 
 * NSString objects and the database only accepts NSData instances.  The entire cache is 
 * asynchronous, and access is synchronized, so multithreaded access is guaranteed not to cause 
 * issues.
 */
@interface PSTLevelDBCache : NSObject

/**
 * Returns an initialized LevelDB Cache object.  If a cache file is not found at the given 
 * path, it is created.  If it is found, it is opened.
 */
- (id)initWithPath:(NSString *)path;

/**
 * Opens the LevelDB database if it is not already opened.  Returns Yes if successful or the 
 * database is already opened and can be written to.
 */
- (BOOL)open;

/**
 * Closes the LevelDB database.
 */
- (void)close;

/**
 * Sets the data of the specified key in the cache.
 */
- (void)setData:(NSData *)data forKey:(NSString *)key;

/**
 * Returns the data associated with a given key.
 */
- (NSData *)dataForKey:(NSString *)key;

/**
 * Removes the data of the specified key in the cache.
 */
- (void)removeDataForKey:(NSString *)key;

@end

@interface PSTLevelDBCache (PSTExtendedCache)

/**
 * Queries the database and returns whether or not the internal LevelDB cache contains a value 
 * for a given key.
 */
- (BOOL)hasDataForKey:(NSString *)key;

@end

/**
 * Adds support for keyed subscripting to the cache.
 */
@interface PSTLevelDBCache (PSTSubscripting)

- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(NSData *)obj forKeyedSubscript:(NSString *)key;

@end
