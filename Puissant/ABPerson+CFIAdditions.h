//
//  ABPerson+CFIAdditions.h
//  DotMail
//
//  Created by Robert Widmann on 7/30/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <AddressBook/AddressBook.h>

@interface ABPerson (CFIAdditions)

- (NSArray*)dm_allEmailsForPerson;

- (NSString*)dm_displayName;
- (NSString*)dm_companyName;
- (NSString*)dm_lastName;
- (NSString*)dm_middleName;
- (NSString*)dm_nickName;
- (NSString*)dm_firstName;

- (NSString*)dm_firstLastName;
- (NSString*)dm_lastFirstName;
- (NSString*)dm_firstMiddleLastName;
- (NSString*)dm_lastMiddleFirstName;

@end
