//
//  PSTCacheSpec.m
//  Puissant
//
//  Created by IDA WIDMANN on 1/1/14.
//  Copyright (c) 2014 CodaFi. All rights reserved.
//

#import <Puissant/PSTCache.h>

SpecBegin(PSTCache)

__block PSTCache *cache;

beforeEach(^{
	cache = [[PSTCache alloc] init];
});

describe(@"pruning", ^{
	it(@"should prune its cache down to maxSize", ^{
		cache.maxSize = 2;
		[cache beginTransaction];
		cache[@"Key1"] = NSColor.whiteColor;
		cache[@"Key2"] = NSColor.whiteColor;
		cache[@"Key3"] = NSColor.whiteColor;
		[cache endTransaction];
		expect(cache.count).to.equal(2);
	});
	
	it(@"should do nothing to its cache when not at maxSize", ^{
		cache.maxSize = 3;
		[cache beginTransaction];
		cache[@"Key1"] = NSColor.whiteColor;
		cache[@"Key2"] = NSColor.whiteColor;
		cache[@"Key3"] = NSColor.whiteColor;
		[cache endTransaction];
		expect(cache.count).to.equal(3);
	});
});


SpecEnd
