//
//  MCOAddress+PSTPrettification.m
//  Puissant
//
//  Created by Robert Widmann on 2/2/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "MCOAddress+PSTPrettification.h"

@implementation MCOAddress (PSTPrettification)

- (NSString*)dm_prettifiedDisplayString {
	if (self.displayName.length == 0) {
		if (self.mailbox == nil) {
			return nil;
		}
		else {
			return self.mailbox;
		}
	}
	else {
		return self.displayName;
	}
	return nil;
}

//A completely formed address object should return a string in the format: "John Doe <john.doe@email.com>"
- (NSString *)prettifiedStringValue {
	if (self.displayName.length == 0) {
		if (self.mailbox == nil) {
			return nil;
		}
		else {
			return [NSString stringWithFormat:@"<%@>", self.mailbox];
		}
	}
	else {
		if (self.mailbox != nil) {
			return [NSString stringWithFormat:@"%@ <%@>", self.displayName, self.mailbox];
		}
		else {
			return self.displayName;
		}
	}
	return nil;
}

- (id)initWithCoder:(NSCoder *)coder
{
	self = [self init];
	
	[self setDisplayName:[coder decodeObjectForKey:@"displayName"]];
	[self setMailbox:[coder decodeObjectForKey:@"mailbox"]];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:[self displayName] forKey:@"displayName"];
	[encoder encodeObject:[self mailbox] forKey:@"mailbox"];
}

@end
