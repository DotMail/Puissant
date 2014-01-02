//
//  NSIndexSet+PSTOperators.m
//  Puissant
//
//  Created by Robert Widmann on 5/25/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "NSIndexSet+PSTOperators.h"

@implementation NSIndexSet (PSTOperators)

- (NSArray *)map:(id(^)(NSUInteger index))mapBlock {
	NSMutableArray *accumulator = @[].mutableCopy;
	[self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		[accumulator addObject:mapBlock(idx)];
	}];
	return accumulator;
}

@end
