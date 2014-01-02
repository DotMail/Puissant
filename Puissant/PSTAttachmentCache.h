//
//  PSTAttachmentPrototype.h
//  Puissant
//
//  Created by Robert Widmann on 3/22/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCOMessageHeader;

@interface PSTAttachmentCache : NSObject

@property (nonatomic, strong) MCOMessageHeader *header;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *filepath;
@property (nonatomic, copy) NSString *rowID;

@property (nonatomic, assign, readonly) BOOL isImage;
@property (nonatomic, assign, readonly) BOOL isArchive;

@end
