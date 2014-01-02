//
//  DMConversationSpec.m
//  Puissant
//
//  Created by Robert Widmann on 5/18/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

SpecBegin(DMConversation)

__block PSTConversation *convo;

before(^{
	convo = [[PSTConversation alloc]init];
});


describe(@"NSCopying", ^{
	it(@"should conform to NSCopying", ^{
		expect([convo conformsToProtocol:@protocol(NSCopying)]).to.beTruthy();
	});
	
	it(@"should implement -copy", ^{
		PSTConversation *convoCopy = convo.copy;
		expect(convoCopy.sortDate).to.equal(convo.sortDate);
		expect(convoCopy.conversationID).to.equal(convo.conversationID);
		expect(convoCopy.folder).to.equal(convo.folder);
		expect(convoCopy.otherFolder).to.equal(convo.otherFolder);
		expect(convoCopy.storage).to.equal(convo.storage);
		expect(convoCopy.mode).to.equal(convo.mode);
		expect(convoCopy.actionStep).to.equal(convo.actionStep);
	});
});

SpecEnd
