//
//  NSArray+StringifyAddress.m
//  Puissant
//
//  Created by Robert Widmann on 1/26/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "NSArray+StringifyAddress.h"
#import <MailCore/mailcore.h>
#import "MCOAddress+PSTPrettification.h"

@implementation NSArray (StringifyAddress)

- (NSString*)dm_AddressDisplayString {
	NSMutableArray *mutableAddresses = [[NSMutableArray alloc]init];
	for (MCOAddress *address in self) {
		[mutableAddresses addObject:[address dm_prettifiedDisplayString]];
	}
	return [mutableAddresses componentsJoinedByString:@", "];
}

@end
