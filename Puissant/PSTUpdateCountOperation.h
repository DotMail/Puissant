//
//  PSTUpdateCountOperation.h
//  DotMail
//
//  Created by Robert Widmann on 10/20/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTStorageOperation.h"

typedef NS_OPTIONS(NSUInteger, PSTUpdateCountOptions) {
	PSTUpdateCountOptionNone = 0,
	PSTUpdateCountOptionUpdateStarred = 1 << 0,
	PSTUpdateCountOptionUpdateImportant = 1 << 1,
	PSTUpdateCountOptionUpdateUnread = 1 << 2,
	PSTUpdateCountOptionUpdateNextSteps = 1 << 3,
	PSTUpdateCountOptionUpdateCached = 1 << 4,
	
	PSTUpdateCountOptionsMask = (PSTUpdateCountOptionUpdateStarred | PSTUpdateCountOptionUpdateImportant | PSTUpdateCountOptionUpdateUnread | PSTUpdateCountOptionUpdateNextSteps | PSTUpdateCountOptionUpdateCached),
};

@interface PSTUpdateCountOperation : PSTStorageOperation

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *trashPath;
@property (nonatomic, assign) PSTUpdateCountOptions options;
@property (nonatomic, assign) NSUInteger count;

@end
