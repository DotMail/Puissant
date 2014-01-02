//
//  NSString+WhitespaceStripping.m
//  Puissant
//
//  Created by Robert Widmann on 2/2/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "NSString+WhitespaceStripping.h"

@implementation NSString (WhitespaceStripping)

- (NSString*)stringByTrimmingLeadingWhitespace {
    if ([self length]==0) return self;
    NSInteger i = 0;
    while ((i < [self length]) && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[self characterAtIndex:i]]) {
        i++;
    }
    return [self substringFromIndex:i];
}

- (NSString*)stringByTrimmingTailingWhitespace {
    if ([self length]==0) return self;
    NSInteger i = 0;
    while ((i < [self length]) && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[self characterAtIndex:[self length]-1-i]]) {
        i++;
    }
    return [self substringWithRange:NSMakeRange(0,[self length]-i)];
}

- (NSString*)stringByTrimmingLeadingAndTailingWhitespace {
    return [[self stringByTrimmingLeadingWhitespace] stringByTrimmingTailingWhitespace];
}

@end
