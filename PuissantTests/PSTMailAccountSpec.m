//
//  DMMailAccountSpec.m
//  Puissant
//
//  Created by Robert Widmann on 7/17/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

SpecBegin(DMMailAccount)

describe(@"Abstract superclass-ness", ^{
	it(@"should be an abstract superclass and throw on -init", ^{
		expect(^{
			PSTMailAccount *account = [[PSTMailAccount alloc]init];
			account = nil;
		}).to.raise(NSInternalInconsistencyException);
	});
	
	it(@"should throw when an unrecognized service is passed", ^{
		expect(^{
			PSTMailAccount *account = [[PSTMailAccount alloc]initWithDictionary:@{ @"FOOPService" : @""}];
			account = nil;
		}).to.raise(NSInvalidArgumentException);
	});
});

SpecEnd
