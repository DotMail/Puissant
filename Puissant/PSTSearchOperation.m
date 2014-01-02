//
//  PSTSearchOperation.m
//  Puissant
//
//  Created by Robert Widmann on 7/5/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTSearchOperation.h"
#import "PSTDatabase.h"
#import "PSTConversation.h"
#import "PSTConversationCache.h"

@implementation PSTSearchOperation {
	NSMutableSet *suggestedSubjects;
	NSMutableSet *suggestedPeopleByMailbox;
	NSMutableSet *suggestedPeopleByDisplayName;
	void (^_callback)(BOOL, NSMutableSet *, NSMutableSet *, NSMutableSet *);
}

- (id)init {
	self = [super init];
	
	suggestedSubjects = [[NSMutableSet alloc]init];
	suggestedPeopleByMailbox = [[NSMutableSet alloc]init];
	suggestedPeopleByDisplayName = [[NSMutableSet alloc]init];
	
	return self;
}

- (void)start:(void (^)(BOOL, NSMutableSet *, NSMutableSet *, NSMutableSet *))callback {
	_callback = callback;
}

- (void)mainRequest {
	if (self.isCancelled) return;
	[self.database beginTransaction];
	[self.database commit];
	if (self.isCancelled) return;
	self.conversations = [self.database searchConversationsWithTerms:self.searchTerms kind:self.kind folder:self.folder.path otherFolder:self.otherFolder.path mainFolders:self.mainFolders mode:self.mode limit:self.limit returningEverything:NO];
	if (self.isCancelled) return;
	if (!self.needsSuggestions) return;
	[self performSelectorOnMainThread:@selector(_showResults) withObject:Nil waitUntilDone:YES];
	NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc]init];
	for (PSTConversation *conversation in self.conversations) {
		[indexSet addIndex:conversation.conversationID];
	}
	NSArray *searchStrings = [self.searchStringToComplete.string componentsSeparatedByString:@" "];
	[indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		PSTConversationCache *cache = [self.database rawConversationCacheForConversationID:idx];
		[cache resolveCachedSendersAndRecipients];
		for (MCOAddress *address in cache.senders) {
			
		}
		for (MCOAddress *address in cache.recipients) {
			
		}
		
		if (cache.subject.lowercaseString) {
			if ([self.database matchSearchStrings:searchStrings withString:cache.subject.lowercaseString]) {
				[suggestedSubjects addObject:cache.subject];
			}
		}
	}];
}

- (void)addAddressSuggestion:(MCOAddress *)address peopleByMailbox:(NSMutableSet *)peopleByMailbox peopleByName:(NSMutableSet *)peopleByName searchStrings:(NSArray *)strings peopleUniquer:(NSMutableSet *)peopleUniquer mailboxUniquer:(NSMutableSet *)mailboxUniquer {
	if (![self.database matchSearchStrings:strings withString:address.displayName]) {
		if (![self.database matchSearchStrings:strings withString:address.mailbox]) {
			return;
		}
		[peopleByMailbox addObject:address];
	}
	[peopleByName addObject:[MCOAddress addressWithDisplayName:address.displayName.lowercaseString mailbox:address.mailbox.lowercaseString]];
	[mailboxUniquer addObject:address.mailbox.lowercaseString];
}

- (void)_showResults {
	if (self.isCancelled) {
		return;
	}
	[self.delegate storageOperationDidUpdateState:self];
}

- (void)mainFinished {
	if (_callback) {
		_callback(self.needsSuggestions, suggestedSubjects, suggestedPeopleByMailbox, suggestedPeopleByDisplayName);
	}
}

@end
