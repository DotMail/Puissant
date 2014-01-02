//
//  PSTLocalAttachment.h
//  Puissant
//
//  Created by Robert Widmann on 11/16/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <MailCore/mailcore.h>

@interface PSTLocalAttachment : MCOAttachment

+ (MCOAbstractMessagePart *)attachmentWithContentsOfFile:(NSString *)filename;

@property (nonatomic, copy) NSString *partID;
@property (nonatomic, copy) NSString *folderPath;
@property (nonatomic, assign, readonly) NSUInteger size;

- (void)commit;
- (void)remove;

@end

