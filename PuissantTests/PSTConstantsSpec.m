//
//  PSTConstantsSpec.m
//  Puissant
//
//  Created by Robert Widmann on 5/25/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

SpecBegin(PSTConstants)

__block NSArray *testHomogenousArray = nil;
__block NSIndexSet *testIndexSet = nil;
__block NSMutableArray *testFoldersArray = nil;

beforeEach(^{
	testHomogenousArray = @[ @"A", @"B", @"C" ];
	testIndexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 100)];
	testFoldersArray = @[].mutableCopy;
	for (int i = 0; i < 100; i++) {
		MCOIMAPFolder *folder = [[MCOIMAPFolder alloc]init];
		folder.path = [NSString stringWithFormat:@"%i", i];
		[testFoldersArray addObject:folder];
	}
	MCOIMAPFolder *inboxFolder = [[MCOIMAPFolder alloc]init];
	inboxFolder.path = @"INBOX";
	[testFoldersArray addObject:inboxFolder];
});

describe(@"DMArrayDivide(3)", ^{
	it(@"should return the given array when not enough parts are specified", ^{
		NSArray *outArray = nil;
		PSTArrayDivide(&outArray, testHomogenousArray, 1);
		expect(outArray).to.equal(@[ testHomogenousArray ]);
		PSTArrayDivide(&outArray, testHomogenousArray, 0);
		expect(outArray).to.equal(@[ testHomogenousArray ]);
	});
	
	it(@"should divide an array into the specified number of parts", ^{
		NSArray *outArray = nil;
		PSTArrayDivide(&outArray, testHomogenousArray, 3);
		expect(outArray).to.haveCountOf(3);
	});
	
	it(@"should return subarrays containing each object", ^{
		NSArray *outArray = nil;
		PSTArrayDivide(&outArray, testHomogenousArray, 3);
		expect(outArray[0]).to.equal(@[ @"A" ]);
		expect(outArray[1]).to.equal(@[ @"B" ]);
		expect(outArray[2]).to.equal(@[ @"C" ]);
	});
});

describe(@"DMPreferentialArrayDivide(3)", ^{
	it(@"should return the given array when not enough parts are specified", ^{
		NSArray *outArray = nil;
		PSTPreferentialArrayDivide(&outArray, testFoldersArray, 1);
		expect(outArray).to.equal(@[ testFoldersArray ]);
		PSTPreferentialArrayDivide(&outArray, testFoldersArray, 0);
		expect(outArray).to.equal(@[ testFoldersArray ]);
	});
	
	it(@"should divide an array into the specified number of parts", ^{
		NSArray *outArray = nil;
		PSTPreferentialArrayDivide(&outArray, testFoldersArray, 3);
		expect(outArray).to.haveCountOf(3);
	});

	it(@"should return subarrays containing each object", ^{
		NSArray *outArray = nil;
		PSTPreferentialArrayDivide(&outArray, testFoldersArray, 3);
		expect([outArray[2][0] path]).to.equal([testFoldersArray[2] path]);
		expect([outArray[1][0] path]).to.equal([testFoldersArray[1] path]);
		expect([outArray[0][0] path]).to.equal([testFoldersArray[0] path]);
	});
	
	it(@"should prefer the inbox folder", ^{
		NSArray *outArray = nil;
		PSTPreferentialArrayDivide(&outArray, testFoldersArray, testFoldersArray.count);
		expect(outArray[0][0]).to.equal(testFoldersArray.lastObject);
	});
});

describe(@"DMReverseArrayDivide(3)", ^{
	it(@"should return the given array when not enough parts are specified", ^{
		NSArray *outArray = nil;
		PSTReverseArrayDivide(&outArray, testHomogenousArray, 1);
		expect(outArray).to.equal(@[ testHomogenousArray ]);
		PSTReverseArrayDivide(&outArray, testHomogenousArray, 0);
		expect(outArray).to.equal(@[ testHomogenousArray ]);
	});
	
	it(@"should divide an array into the specified number of parts", ^{
		NSArray *outArray = nil;
		PSTReverseArrayDivide(&outArray, testHomogenousArray, 3);
		expect(outArray).to.haveCountOf(3);
	});
	
	it(@"should return subarrays containing each object", ^{
		NSArray *outArray = nil;
		PSTReverseArrayDivide(&outArray, testHomogenousArray, 3);
		expect(outArray[2]).to.equal(@[ @"A" ]);
		expect(outArray[1]).to.equal(@[ @"B" ]);
		expect(outArray[0]).to.equal(@[ @"C" ]);
	});
});

describe(@"PSTIndexSetDivide(3)", ^{
	it(@"should return a singleton array when not enough parts are specified", ^{
		NSArray *outArray = nil;
		PSTIndexSetDivide(&outArray, testIndexSet, 1);
		expect(outArray).to.contain(testIndexSet);
		expect(outArray).to.haveCountOf(1);
		PSTIndexSetDivide(&outArray, testIndexSet, 0);
		expect(outArray).to.contain(testIndexSet);
		expect(outArray).to.haveCountOf(1);
	});
	
	it(@"should divide an index set into the specified number of parts", ^{
		NSArray *outArray = nil;
		PSTIndexSetDivide(&outArray, testIndexSet, 3);
		expect(outArray).to.haveCountOf(3);
	});
	
	it(@"should return sub-indexSets containing each range", ^{
		NSArray *outArray = nil;
		PSTIndexSetDivide(&outArray, testIndexSet, 3);
		expect([outArray[0] firstIndex]).to.equal(0);
		expect([outArray[1] firstIndex]).to.equal(33);
		expect([outArray[2] firstIndex]).to.equal(66);
		expect([outArray[2] lastIndex]).to.equal(99);
	});
});

describe(@"PSTReverseIndexSetDivide", ^{
	it(@"should return a singleton array when not enough parts are specified", ^{
		NSArray *outArray = nil;
		PSTReverseIndexSetDivide(&outArray, testIndexSet, 1);
		expect(outArray).to.contain(testIndexSet);
		expect(outArray).to.haveCountOf(1);
		PSTReverseIndexSetDivide(&outArray, testIndexSet, 0);
		expect(outArray).to.contain(testIndexSet);
		expect(outArray).to.haveCountOf(1);
	});
	
	it(@"should divide a reversed index set into the specified number of parts", ^{
		NSArray *outArray = nil;
		PSTReverseIndexSetDivide(&outArray, testIndexSet, 3);
		expect(outArray).to.haveCountOf(3);
	});
	
	it(@"should return reversed sub-indexSets containing each range", ^{
		NSArray *outArray = nil;
		PSTReverseIndexSetDivide(&outArray, testIndexSet, 3);
		expect([outArray[2] firstIndex]).to.equal(0);
		expect([outArray[1] firstIndex]).to.equal(33);
		expect([outArray[0] lastIndex]).to.equal(99);
	});
});

SpecEnd
