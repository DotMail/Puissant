//
//  DMAvatarImageManagerSpec.m
//  Puissant
//
//  Created by Robert Widmann on 5/23/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

SpecBegin(DMAvatarImageManager)

__block PSTAvatarImageManager *imageManager = nil;

before(^{
	imageManager = PSTAvatarImageManager.defaultManager;
});

it(@"should be a singleton", ^{
	expect(imageManager).to.equal(PSTAvatarImageManager.defaultManager);
});

SpecEnd
