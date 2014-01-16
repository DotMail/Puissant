//
//  PSTSearchQueryTransformer.h
//  Puissant
//
//  Created by Robert Widmann on 1/15/14.
//  Copyright (c) 2014 CodaFi. All rights reserved.
//


PUISSANT_EXPORT NSString *const PSTQueryToSQLQueryTransformerName;

@interface PSTSearchQueryTransformer : NSValueTransformer

- (NSString *)transformedValue:(NSString *)value;

@end
