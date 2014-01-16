//
//  PSTSearchQueryTransformer.m
//  Puissant
//
//  Created by Robert Widmann on 1/15/14.
//  Copyright (c) 2014 CodaFi. All rights reserved.
//

#import "PSTSearchQueryTransformer.h"

NSString *const PSTQueryToSQLQueryTransformerName = @"PSTQueryToSQLQueryTransformerName";

@implementation PSTSearchQueryTransformer

+ (void)load {
	@autoreleasepool {
		[NSValueTransformer setValueTransformer:PSTSearchQueryTransformer.new forName:PSTQueryToSQLQueryTransformerName];
	}
}

- (NSString *)transformedValue:(NSString *)value {
	return [NSString stringWithFormat:@"select rowid from message where %@ order by date desc", @"is_read = 1"];
}

+ (BOOL)allowsReverseTransformation {
	return NO;
}

@end
