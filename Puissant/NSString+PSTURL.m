//
//  NSString+PSTURL.m
//  Puissant
//
//  Created by Robert Widmann on 11/23/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "NSString+PSTURL.h"
#import <MailCore/mailcore.h>

@implementation NSString (PSTURL)

- (NSString*)dmEncodedURLValue {
	return (__bridge NSString *)(CFURLCreateStringByAddingPercentEscapes(CFAllocatorGetDefault(), (__bridge CFStringRef)(self), NULL, (__bridge CFStringRef)@"$&+,/:;=?@[]#!'()*", kCFStringEncodingUTF8));
}

@end
