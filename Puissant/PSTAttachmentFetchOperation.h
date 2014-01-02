//
//  PSTAttachmentFetchOperation.h
//  Puissant
//
//  Created by Robert Widmann on 3/22/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTStorageOperation.h"

@class MCOIMAPFolder;

typedef NS_ENUM(NSUInteger, PSTAttachmentFetchMode) {
	PSTAttachmentFetchModeAll,
	PSTAttachmentFetchModeForFolder,
	PSTAttachmentFetchModeSearch
};


@interface PSTAttachmentFetchOperation : PSTStorageOperation

- (void)start:(void(^)(NSArray *))callback;

@property (nonatomic, assign) PSTAttachmentFetchMode mode;
@property (nonatomic, strong) MCOIMAPFolder *allMailfolder;
@property (nonatomic, strong) MCOIMAPFolder *trashFolder;
@property (nonatomic, strong) MCOIMAPFolder *selectedFolder;

@end
