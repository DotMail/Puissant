//
//  PSTModifiedMessagesOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/24/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTModifiedMessagesOperation.h"
#import "PSTDatabase.h"
#import <MailCore/mailcore.h>

@interface PSTModifiedMessagesOperation ()

@property (nonatomic, strong) NSMutableArray *messagesToDelete;
@property (nonatomic, strong) NSMutableArray *messagesToPurge;
@property (nonatomic, strong) NSMutableArray *messagesToModify;
@property (nonatomic, strong) NSMutableArray *messagesToCopyItems;

@end

@implementation PSTModifiedMessagesOperation {
	void(^_callback)(NSMutableArray *mDelete, NSMutableArray *mPurge, NSMutableArray *mModify, NSMutableArray *mCopy);
}

- (void)start:(void(^)(NSMutableArray *mDelete, NSMutableArray *mPurge, NSMutableArray *mModify, NSMutableArray *mCopy))callback {
	_callback = callback;
	[super startRequest];
}

- (void)mainRequest {
	NSDictionary *modifyDict = [self.database messagesToModifyDictionaryForFolder:self.folder];
	self.messagesToDelete = [modifyDict objectForKey:@"Delete"];
	self.messagesToPurge = [modifyDict objectForKey:@"Purge"];
	self.messagesToModify = [modifyDict objectForKey:@"Modify"];
}

- (void)mainFinished {
	if (_callback) {
		_callback(self.messagesToDelete, self.messagesToPurge, self.messagesToModify, self.messagesToCopyItems);
	}
}

@end
