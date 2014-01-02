//
//  PSTDystopiaSearchMetaDatabase.h
//  Puissant
//
//  Created by Robert Widmann on 3/23/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TokyoCabinet/dystopia.h>

@class PSTLevelDBCache;

@interface PSTDystopiaSearchMetaDatabase : NSObject

@property (nonatomic, strong) PSTLevelDBCache *hashFile;
@property (nonatomic, copy) NSString *prefix;

- (id)initWithPath:(NSString *)path;

/**
 * Adds a given index-value pair to the map table.
 */
- (void)setMetaData:(NSString*)data forIndex:(NSUInteger)index;

/**
 * Returns a the value associated with a given index.
 */
- (NSData *)metaDataForIndex:(NSUInteger)idx;

/**
 * Removes a given index and its associated value from the map table.
 */
- (void)removeMetaDataForIndex:(NSUInteger)index;


@end

@interface PSTDystopiaSearchMetaDatabase (PSTExtendedSearchMetaDatabase)

/**
 * Returns whether or not the internal Tokyo Cabinet cache contains a value for a given index.
 */
- (BOOL)hasMetaDataForIndex:(NSUInteger)idx;

@end

/**
 * Adds support for keyed subscripting to the cache.
 */
@interface PSTDystopiaSearchMetaDatabase (PSTSubscripting)

- (id)objectAtIndexedSubscript:(NSUInteger)key;
- (void)setObject:(NSString*)obj forKeyedSubscript:(NSUInteger)key;

@end

