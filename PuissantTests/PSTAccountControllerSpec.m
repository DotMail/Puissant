//
//  DMAccountControllerSpec.m
//  Puissant
//
//  Created by Robert Widmann on 5/7/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

SpecBegin(DMAccountController)

__block PSTAccountController *testAccountController = nil;
__block PSTMailAccount *testAccount = nil;
static NSString *const testEmail = @"xyz123@gmail.com";

before(^{
	testAccount = [[PSTMailAccount alloc]initWithDictionary:@{
				   @"Name": @"Test Name",
				   @"Email" : testEmail,
				   @"IMAPService" : @{},
				   }];
	testAccountController = [[PSTAccountController alloc]initWithAccount:testAccount];
});

describe(@"Account Manager", ^{
	it(@"should manage an array of accounts", ^{
		expect(testAccountController.accounts).notTo.beNil();
	});
	
	it(@"should return its first account as its main account", ^{
		expect(testAccountController.mainAccount).to.equal(testAccount);
	});
});

SpecEnd
