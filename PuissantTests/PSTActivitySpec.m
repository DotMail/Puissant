//
//  DMActivitySpec.m
//  Puissant
//
//  Created by Robert Widmann on 5/26/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Puissant/PSTActivity.h>

SpecBegin(PSTActivity)

describe(@"Convenience initializers", ^{
	it(@"should create an activity with a description and an email", ^{
		PSTActivity *activity = [PSTActivity activityWithDescription:@"Description" forEmail:@"abc@xyz.com"];
		expect(activity.activityDescription).to.equal(@"Description");
		expect(activity.email).to.equal(@"abc@xyz.com");
	});
	
	it(@"should create an activity with a description and a folder path", ^{
		PSTActivity *activity = [PSTActivity activityWithDescription:@"Description" forFolderPath:@"INBOX" email:@"test@gmail.com"];
		expect(activity.activityDescription).to.equal(@"Description");
		expect(activity.folderPath).to.equal(@"INBOX");
	});
});

describe(@"progress", ^{
	it(@"should set a maximum progress value", ^{
		PSTActivity *activity = [PSTActivity activityWithDescription:@"Description" forFolderPath:@"INBOX" email:@"test@gmail.com"];
		[activity setMaximumProgress:100.f];
		expect(activity.maximumProgress).to.equal(100.f);
	});
	
	it(@"should set a progress value", ^{
		PSTActivity *activity = [PSTActivity activityWithDescription:@"Description" forFolderPath:@"INBOX" email:@"test@gmail.com"];
		[activity setMaximumProgress:100.f];
		activity.progressValue = 25.f;
		expect(activity.progressValue).to.equal(25.f);
		expect(activity.percentValue).to.equal(25.f/100.f);
		activity.progressValue = 50.f;
		expect(activity.progressValue).to.equal(50.f);
		expect(activity.percentValue).to.equal(50.f/100.f);
		activity.progressValue = 75.f;
		expect(activity.progressValue).to.equal(75.f);
		expect(activity.percentValue).to.equal(75.f/100.f);
		activity.progressValue = 100.f;
		expect(activity.progressValue).to.equal(100.f);
		expect(activity.percentValue).to.equal(100.f/100.f);
	});
	
	it(@"should increment its progress value", ^{
		PSTActivity *activity = [PSTActivity activityWithDescription:@"Description" forFolderPath:@"INBOX" email:@"test@gmail.com"];
		[activity setMaximumProgress:100.f];
		[activity incrementProgressValue:25.f];
		expect(activity.progressValue).to.equal(25.f);
		expect(activity.percentValue).to.equal(25.f/100.f);
	});
});

SpecEnd
