//
//  PSTSaveCachedFlagsOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTSaveCachedFlagsOperation.h"
#import "PSTDatabase.h"
#import <MailCore/mailcore.h>

@implementation PSTSaveCachedFlagsOperation

- (void)mainRequest {
	NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
	for (MCOIMAPMessage *message in self.messages) {
		[dict setObject:@(message.flags) forKey:[NSString stringWithFormat:@"%u", message.uid]];
	}
	self.messagesDict = dict;
	[self.database saveCachedMessageFlags:dict forPath:self.path];
}

@end
