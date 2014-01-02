//
//  ABPerson+CFIAdditions.m
//  DotMail
//
//  Created by Robert Widmann on 7/30/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "ABPerson+CFIAdditions.h"

@implementation ABPerson (CFIAdditions)

- (NSArray*)dm_allEmailsForPerson {
	NSMutableArray *retVal = [NSMutableArray array];
	
	ABMultiValue *emails = [self valueForKey:kABEmailProperty];
	if (emails.count != 0) {
		for (int i = 0; i < emails.count; i++) {
			[retVal addObject:[emails valueAtIndex:i]];
		}
	}
	
	return retVal;
}

- (BOOL)dm_firstNameFirst {
	if ((self.dm_flags & kABLastNameFirst) == NO) {
		return [self.class dm_firstNameFirst];
	} else {
		return (self.dm_flags & kABFirstNameFirst);
	}
	
	return NO;
}

- (BOOL)dm_lastNameFirst {
	if ((self.dm_flags & kABLastNameFirst) == NO) {
		return ![self.class dm_firstNameFirst];
	} else {
		return (self.dm_flags & kABLastNameFirst);
	}
	
	return NO;
}

+ (BOOL)dm_firstNameFirst {
	return (ABAddressBook.sharedAddressBook.defaultNameOrdering == kABFirstNameFirst);
}

- (int)dm_flags {
	return [[self valueForProperty:kABPersonFlags]intValue];
}

- (BOOL)dm_showAsCompany {
	return ([self dm_flags] & kABShowAsCompany);
}

- (NSString*)dm_companyName {
	return [self valueForProperty:kABOrganizationProperty];
}

- (NSString*)dm_lastName {
	return [self valueForProperty:kABLastNameProperty];
}

- (NSString*)dm_middleName {
	return [self valueForProperty:kABMiddleNameProperty];
}

- (NSString*)dm_nickName {
	return [self valueForProperty:kABNicknameProperty];
}

- (NSString*)dm_firstName {
	return [self valueForProperty:kABFirstNameProperty];
}

- (NSString*)dm_displayName {
	if ([self dm_showAsCompany]) {
		return [self dm_companyName];
	} else {
		if ([self dm_firstNameFirst]) {
			return [self dm_firstMiddleLastName];
		} else {
			return [self dm_lastMiddleFirstName];
		}
	}
	return nil;
}

- (NSString*)dm_firstLastName {
	NSMutableString *retVal = [NSMutableString string];
	if ([self dm_firstName] != nil) {
		[retVal appendString:[self dm_firstName]];
	}
	if ([self dm_lastName] != nil) {
		if ([self dm_lastName].length != 0) {
			[retVal appendString:@" "];
		}
		[retVal appendString:[self dm_lastName]];
	}
	if (retVal.length == 0) {
		return nil;
	}
	return retVal;
}

- (NSString*)dm_lastFirstName {
	NSMutableString *retVal = [NSMutableString string];
	if ([self dm_lastName] != nil) {
		[retVal appendString:[self dm_lastName]];
	}
	if ([self dm_firstName] != nil) {
		if ([self dm_firstName].length != 0) {
			[retVal appendString:@" "];
		}
		[retVal appendString:[self dm_firstName]];
	}
	if (retVal.length == 0) {
		return nil;
	}
	return retVal;
}

- (NSString*)dm_firstMiddleLastName {
	NSMutableString *retVal = [NSMutableString string];
	if ([self dm_firstName] != nil) {
		[retVal appendString:[self dm_firstName]];
	}
	if ([self dm_middleName] != nil) {
		if ([self dm_middleName].length != 0) {
			[retVal appendString:@" "];
		}
		[retVal appendString:[self dm_middleName]];
	}
	if ([self dm_lastName] != nil) {
		if ([self dm_lastName].length != 0) {
			[retVal appendString:@" "];
		}
		[retVal appendString:[self dm_lastName]];
	}
	if (retVal.length == 0) {
		return nil;
	}
	return retVal;
}

- (NSString*)dm_lastMiddleFirstName {
	NSMutableString *retVal = [NSMutableString string];
	if ([self dm_lastName] != nil) {
		[retVal appendString:[self dm_lastName]];
	}
	if ([self dm_middleName] != nil) {
		if ([self dm_middleName].length != 0) {
			[retVal appendString:@" "];
		}
		[retVal appendString:[self dm_middleName]];
	}
	if ([self dm_firstName] != nil) {
		if ([self dm_firstName].length != 0) {
			[retVal appendString:@" "];
		}
		[retVal appendString:[self dm_firstName]];
	}
	if (retVal.length == 0) {
		return nil;
	}
	return retVal;
}

@end
