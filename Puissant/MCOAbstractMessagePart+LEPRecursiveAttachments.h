//
//  MCOAbstractMessagePart+LEPRecursiveAttachments.h
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <MailCore/MCOAbstractMessagePart.h>

@class PSTMailAccount, WebView, MCOIMAPMessage;

@interface MCOAbstractMessagePart (LEPRecursiveAttachments)

- (NSArray *)allAttachments;
- (NSArray *)plaintextTypeAttachments;
- (NSArray *)calendarTypeAttachments;
- (NSArray *)attachmentsWithContentIDs;

@end

