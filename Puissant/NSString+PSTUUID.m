//
//  NSString+PSTUUID.m
//  DotMail
//
//  Created by Robert Widmann on 10/19/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "NSString+PSTUUID.h"

@implementation NSString (PSTUUID)

+ (NSString *)dmUUIDString {
	CFUUIDRef udid = CFUUIDCreate(NULL);
	NSString *udidString = (__bridge NSString *)CFUUIDCreateString(NULL, udid);
	CFRelease(udid);
	
	return udidString;
}

@end
