//
//  PSTCommitFlagsOperation.m
//  Puissant
//
//  Created by Robert Widmann on 4/2/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTCommitFlagsOperation.h"
#import "PSTDatabase.h"
#import <MailCore/MCOIMAPFolder.h>

@implementation PSTCommitFlagsOperation

- (void)mainRequest {
	for (MCOIMAPMessage *message in self.modifiedMessages) {
//		[self.database commitMessageFlags:message forFolder:self.folder.path];
		[self.database cacheOriginalFlagsFromMessage:(MCOAbstractMessage*)message inFolder:self.folder.path];
	}
}

@end
