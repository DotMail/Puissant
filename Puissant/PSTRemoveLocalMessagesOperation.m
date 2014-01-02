//
//  PSTRemoveLocalMessagesOperation.m
//  Puissant
//
//  Created by Robert Widmann on 1/27/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTRemoveLocalMessagesOperation.h"
#import "PSTDatabase.h"

@implementation PSTRemoveLocalMessagesOperation

- (void)mainRequest {
	[self.database beginTransaction];
	[self.database removeLocalMessagesForFolderPath:self.path];
	[self.database commit];
}

@end
