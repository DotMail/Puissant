//
//  NSString+PSTSearch.m
//  Puissant
//
//  Created by Robert Widmann on 11/13/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "NSString+PSTSearch.h"

@implementation NSString (PSTSearch)

- (BOOL)dmMatchSearchStrings:(NSArray *)strings {
	if (self.length == 0) {
		return NO;
	}
	for (NSString *string in strings) {
		if (string.length == 0) {
			continue;
		}
		if ([self rangeOfString:string options:NSCaseInsensitiveSearch].length <= 0) {
			return NO;
		}
	}
	return YES;
}

@end
