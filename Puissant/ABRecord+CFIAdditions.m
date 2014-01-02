//
//  ABRecord+CFIAdditions.m
//  Puissant
//
//  Created by Robert Widmann on 1/1/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "ABRecord+CFIAdditions.h"

@implementation ABRecord (CFIAdditions)

- (NSString *)ak_fullName {
	NSString *firstName = [self valueForProperty:kABFirstNameProperty];
	NSString *lastName = [self valueForProperty:kABLastNameProperty];
	NSString *company = [self valueForProperty:kABOrganizationProperty];
	NSInteger personFlags = [[self valueForProperty:kABPersonFlags] integerValue];
	BOOL isPerson = (personFlags & kABShowAsMask) == kABShowAsPerson;
	BOOL isCompany = (personFlags & kABShowAsMask) == kABShowAsCompany;
	
	ABAddressBook *AB = [ABAddressBook sharedAddressBook];
	NSString *theString = nil;
	if (isPerson) {
		if ([firstName length] > 0 && [lastName length] > 0) {
			if ([AB defaultNameOrdering] == kABFirstNameFirst) {
				theString = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
			} else {
				theString = [NSString stringWithFormat:@"%@ %@", lastName, firstName];
			}
		} else if ([firstName length] > 0) {
			theString = firstName;
		} else if ([lastName length] > 0) {
			theString = lastName;
		}
		
	} else if (isCompany) {
		if ([company length] > 0) {
			theString = company;
		}
	}
	
	return theString;
}

@end
