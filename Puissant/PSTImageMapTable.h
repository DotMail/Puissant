//
//  PSTAvatarMapTable.h
//  Puissant
//
//  Created by Robert Widmann on 4/12/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSTLevelDBMapTable.h"

@interface PSTImageMapTable : PSTLevelDBMapTable

+ (instancetype) defaultMapTable;

- (void)setImage:(NSImage*)image forEmail:(NSString *)key;

- (NSImage *)imageForEmail:(NSString *)key;

/**
 * Adds a given index-value pair to the map table.
 */
- (void)setImage:(NSImage *)image forKey:(NSString *)key;

/**
 * Returns a the value associated with a given index.
 */
- (NSImage *)imageForKey:(NSString *)key;

///**
// * Removes a given index and its associated value from the map table.
// */
//- (void)removeDataForIndex:(NSUInteger)index;

@end