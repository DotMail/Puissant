//
//  PSTSearchParser.m
//  Puissant
//
//  Created by Robert Widmann on 11/13/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTSearchParser.h"
#import "PSTSearchTerm.h"

@interface PSTSearchParser ()

@property (nonatomic, strong) NSMutableArray *folders;
@property (nonatomic, strong) NSMutableArray *subjects;
@property (nonatomic, strong) NSMutableArray *from;
@property (nonatomic, strong) NSMutableArray *recipient;
@property (nonatomic, strong) NSMutableArray *people;
@property (nonatomic, strong) NSMutableArray *content;
@property (nonatomic, strong) NSMutableArray *attachmentFilenames;
@property (nonatomic, strong) NSMutableArray *searchString;

@property (nonatomic, strong) NSDictionary *mainFolderMapping;
@property (nonatomic, strong) NSDictionary *keywordMapping;
@property (nonatomic, strong) NSDictionary *periodMapping;

@end

@implementation PSTSearchParser

- (id)init { 
	self = [super init];
	
	_folders = @[].mutableCopy;
	_subjects = @[].mutableCopy;
	_from = @[].mutableCopy;
	_recipient = @[].mutableCopy;
	_people = @[].mutableCopy;
	_content = @[].mutableCopy;
	_attachmentFilenames = @[].mutableCopy;
	_searchString = @[].mutableCopy;
	_mainFolderMapping = @{ @"inbox" : @(0xe),
							@"sent" : @(0xf),
							@"draft" : @(0x10),
							@"important" : @(0x11),
							@"spam" : @(0x12),
							@"trash" : @(0x13),
						  };
	
	_keywordMapping = @{ @"starred" : @(0x0),
						 @"favorite" : @(0x0),
						 @"flagged" : @(0x0),
						 @"unread" : @(0x1),
						 @"unseen" : @(0x1),
						 @"read" : @(0x1),
						 @"seen" : @(0x2),
						 @"attachment" : @(0x3),
					  };
	
	_periodMapping = @{ @"last year" : @(0x15),
						@"last month" : @(0x16),
						@"last week" : @(0x17),
						@"this year" : @(0x18),
						@"this month" : @(0x19),
						@"this week" : @(0x1a),
						@"today" : @(0x1b),
						@"yesterday" : @(0x1c),
						@"monday" : @(0x1d),
						@"tuesday" : @(0x1e),
						@"wednesday" : @(0x1f),
						@"thursday" : @(0x20),
						@"friday" : @(0x21),
						@"saturday" : @(0x22),
						@"sunday" : @(0x23)
					  };
	
	return self;
}

- (void)_reset {
	[_folders removeAllObjects];
	[_subjects removeAllObjects];
	[_from removeAllObjects];
	[_recipient removeAllObjects];
	_people = @[].mutableCopy;
	[_content removeAllObjects];
	[_attachmentFilenames removeAllObjects];
	[_searchString removeAllObjects];
}

//TODO
- (void)parseTerms:(NSArray *)terms {
	[self _reset];
	NSMutableArray *mutableTerms = terms.mutableCopy;
	if (mutableTerms.count >= 2) {
		for (int i = 0; i < mutableTerms.count; i++) {
			PSTSearchTerm *term = [mutableTerms objectAtIndex:i];
			if (term.kind == 0xb) {
				PSTSearchTerm *nextTerm = [mutableTerms objectAtIndex:i + 1];
				if (nextTerm.kind == 0xb) {
					//
				}
			}
		}
	}
	
}

@end
