//
//  PSTLoadCachedFlagsOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTLoadCachedFlagsOperation.h"
#import "PSTDatabase.h"
#import <MailCore/mailcore.h>

@interface PSTLoadCachedFlagsOperation ()

@property (nonatomic, strong) NSArray *messageUIDs;

@end

@implementation PSTLoadCachedFlagsOperation

- (void)mainRequest {
	if (self.importMode) {

	} else {
		@autoreleasepool {
			self.messageUIDs = [self.database diffCachedMessageFlagsForPath:self.path withMessage:self.messages];
			NSSet *msgUIDs = [[NSSet alloc]initWithArray:self.messageUIDs];
			NSMutableArray *array = [[NSMutableArray alloc]init];
			for (MCOIMAPMessage *message in self.messages) {
				if ([msgUIDs containsObject:@(message.uid)]) {
					[array addObject:message];
				}
			}
			self.messagesFlags = array;
		}
	}
}

@end
