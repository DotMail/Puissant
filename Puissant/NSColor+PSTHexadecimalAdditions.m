//
//  NSColor+PSTHexadecimalAdditions.m
//  Puissant
//
//  Created by Robert Widmann on 1/11/14.
//  Copyright (c) 2014 CodaFi. All rights reserved.
//

#import "NSColor+PSTHexadecimalAdditions.h"

@implementation NSColor (PSTHexadecimalAdditions)

+ (NSColor *)colorWithHexColorString:(NSString *)inColorString {
	NSColor* result = nil;
	unsigned colorCode = 0;
	unsigned char redByte, greenByte, blueByte;
	
	if (nil != inColorString) {
		NSScanner* scanner = [NSScanner scannerWithString:inColorString];
		(void) [scanner scanHexInt:&colorCode]; // ignore error
	}
	redByte = (unsigned char)(colorCode >> 16);
	greenByte = (unsigned char)(colorCode >> 8);
	blueByte = (unsigned char)(colorCode); // masks off high bits
	
	result = [NSColor
			  colorWithCalibratedRed:(CGFloat)redByte / 0xff
			  green:(CGFloat)greenByte / 0xff
			  blue:(CGFloat)blueByte / 0xff
			  alpha:1.0];
	return result;
}

- (NSString *)hexadecimalValue {
	double redFloatValue, greenFloatValue, blueFloatValue;
	int redIntValue, greenIntValue, blueIntValue;
	NSString *redHexValue, *greenHexValue, *blueHexValue;
	
	NSColor *convertedColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	if(convertedColor) {
		[convertedColor getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];
		
		redIntValue = (int)(redFloatValue*255.99999f);
		greenIntValue = (int)(greenFloatValue*255.99999f);
		blueIntValue = (int)(blueFloatValue*255.99999f);
		
		redHexValue = [NSString stringWithFormat:@"%02x", redIntValue];
		greenHexValue = [NSString stringWithFormat:@"%02x", greenIntValue];
		blueHexValue = [NSString stringWithFormat:@"%02x", blueIntValue];
		
		return [NSString stringWithFormat:@"#%@%@%@", redHexValue, greenHexValue, blueHexValue];
	}
	
	return nil;
}

+ (NSColor *)colorFromHexadecimalValue:(NSString *)hex { 
	if ([hex hasPrefix:@"#"]) {
		hex = [hex substringWithRange:NSMakeRange(1, [hex length] - 1)];
	}
	
	unsigned int colorCode = 0;
	
	if (hex) {
		NSScanner *scanner = [NSScanner scannerWithString:hex];
		(void)[scanner scanHexInt:&colorCode];
	}
	
	return [NSColor colorWithDeviceRed:((colorCode>>16)&0xFF)/255.0 green:((colorCode>>8)&0xFF)/255.0 blue:((colorCode)&0xFF)/255.0 alpha:1.0];
}


@end
