//
//  PSTUpdateCountOperation.m
//  Puissant
//
//  Created by Robert Widmann on 11/24/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTUpdateCountOperation.h"
#import "PSTDatabase.h"

@implementation PSTUpdateCountOperation

- (void)mainRequest {
	if (self.options & PSTUpdateCountOptionUpdateCached) {
		switch (self.options & PSTUpdateCountOptionsMask) {
			case PSTUpdateCountOptionUpdateStarred:
				self.count = [self.database cachedCountForStarredNotInTrashFolderPath:self.trashPath];
				[self.database setCountForStarred:self.count];
				break;
			case PSTUpdateCountOptionUpdateImportant:
				[NSException raise:NSInvalidArgumentException format:@"PSTUpdateCountOptionUpdateImportant is not supported"];
				break;
			case PSTUpdateCountOptionUpdateUnread:
				self.count = [self.database cachedUnseenCountForPath:self.path];
				[self.database setCachedCount:self.count forPath:self.path];
				break;
			case PSTUpdateCountOptionUpdateNextSteps:
				self.count = [self.database cachedCountForNextStepsNotInTrashFolderPath:self.trashPath];
				[self.database setCountForNextSteps:self.count];
				break;
			default:
				self.count = [self.database cachedCountForPath:self.path];
				[self.database setCachedCount:self.count forPath:self.path];
				break;
		}
	} else {
		switch (self.options & PSTUpdateCountOptionsMask) {
			case PSTUpdateCountOptionUpdateStarred:
				self.count = [self.database countForStarredNotInTrashFolderPath:self.trashPath];
				[self.database setCountForStarred:self.count];
				break;
			case PSTUpdateCountOptionUpdateImportant:
				[NSException raise:NSInvalidArgumentException format:@"PSTUpdateCountOptionUpdateImportant is not supported"];
				break;
			case PSTUpdateCountOptionUpdateUnread:
				self.count = [self.database unseenCountForPath:self.path];
				[self.database setCachedCount:self.count forPath:self.path];
				break;
			case PSTUpdateCountOptionUpdateNextSteps:
				self.count = [self.database countForNextStepsNotInTrashFolderPath:self.trashPath];
				[self.database setCountForNextSteps:self.count];
				break;
			default:
				self.count = [self.database countForPath:self.path];
				[self.database setCount:self.count forPath:self.path];
				break;
		}
	}
}

@end
