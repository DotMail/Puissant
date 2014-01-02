//
//  DMAddressBookManagerSpec.m
//  Puissant
//
//  Created by Robert Widmann on 5/14/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

SpecBegin(DMAddressBookManager)

before(^{
	[PSTAddressBookManager sharedManager];
});

it(@"should be a singleton", ^{
	expect(PSTAddressBookManager.sharedManager).to.equal(PSTAddressBookManager.sharedManager);
});

it(@"should search through its address list", ^{
	expect([PSTAddressBookManager.sharedManager search:@""]).to.haveCountOf(0);
	expect([PSTAddressBookManager.sharedManager search:@""]).notTo.beNil();
});

SpecEnd
