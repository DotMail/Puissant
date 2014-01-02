//
//  PSTLocalMessage.h
//  Puissant
//
//  Created by Robert Widmann on 11/22/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <MailCore/mailcore.h>

@class MCOIMAPFolder;

@interface PSTLocalMessage : MCOMessageBuilder <NSCopying>

@property (nonatomic, copy) NSString *folderPath;
@property (nonatomic, retain) MCOIMAPFolder * folder;
@property (nonatomic, assign) MCOMessageFlag flags;
@property (nonatomic, assign) MCOMessageFlag originalFlags;

- (uint64_t)estimatedSize;
- (void)remove;
@end
