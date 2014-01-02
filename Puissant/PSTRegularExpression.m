#if 0
//
//  PSTRegularExpression.m
//  Puissant
//
//  Created by Robert Widmann on 11/23/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTRegularExpression.h"

@implementation PSTRegularExpression

+ (NSString *)escapedPatternForString:(NSString *)string {
	NSCharacterSet *escapeCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"*?+[(){}^$|\\./"];
	NSMutableString *result = [NSMutableString stringWithString:string];
	NSRange rnge;
	while ((rnge = [string rangeOfCharacterFromSet:escapeCharacterSet]).length != NSNotFound) {
		[result insertString:@"\\" atIndex:rnge.location];
	}
}

@end
#endif
