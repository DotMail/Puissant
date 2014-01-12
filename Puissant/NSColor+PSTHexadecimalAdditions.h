//
//  NSColor+PSTHexadecimalAdditions.h
//  Puissant
//
//  Created by Robert Widmann on 1/11/14.
//  Copyright (c) 2014 CodaFi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSColor (PSTHexadecimalAdditions)

- (NSString *)hexadecimalValue;
+ (NSColor *)colorFromHexadecimalValue:(NSString *)hex;
+ (NSColor*)colorWithHexColorString:(NSString *)inColorString;

@end
