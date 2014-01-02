//
//  PSTLRUCache.h
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * An PSTCache object is an NSDictionary-like container, or cache, that stores 
 * key-value pairs.  Developers often incorporate caches to temporarily store 
 * objects with transient data that are expensive to create. Reusing these 
 * objects can provide performance benefits, because their values do not have to
 * be recalculated.
 *
 * Cached objects live for a limited but developer-defined limit (settable with
 * the `maxSize` property).  Once this limit has been hit, the cache is pruned
 * and old entries are released.
 */
@interface PSTCache : NSObject

/// Sets the value of the specified key in the cache.
- (void)setObject:(id)object forKey:(id)aKey;

/// Returns the value associated with a given key.
- (id)objectForKey:(id)aKey;

/// Removes the value of the specified key in the cache.
- (void)removeObjectForKey:(id)aKey;

/// Empties the cache.
- (void)removeAllObjects;

/// Begins a transaction with the cache.
- (void)beginTransaction;

/// Commits a transaction to the cache.
- (void)endTransaction;

/// Returns an array of all keys held by this cache.
- (NSArray *)allKeys;

/// Returns an array of all objects held by this cache.
- (NSArray *)allObjects;

@property (nonatomic, assign) NSUInteger maxSize; //Defaults to 100
@property (nonatomic, assign, readonly) NSUInteger count;

@end

@interface PSTCache (PSTBlockOperations)

/// Applies a given block object to the entries of the dictionary.
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block;
- (void)enumerateKeysAndObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id key, id obj, BOOL *stop))block;

@end

/**
 * Adds support for key subscripting to the cache.
 */
@interface PSTCache (PSTSubscripting)

- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)obj forKeyedSubscript:(id)key;

@end
