//
//  PSTAddMessageContentOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/21/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTAddMessageContentOperation.h"
#import "PSTDatabase.h"

@implementation PSTAddMessageContentOperation

- (void)mainRequest {
	[self.database setContent:self.data forMessage:self.message inFolder:self.path];
}

@end
