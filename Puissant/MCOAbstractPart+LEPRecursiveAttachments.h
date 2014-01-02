//
//  MCOAbstractPart+LEPRecursiveAttachments.h
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <MailCore/MCOAbstractPart.h>
#import <MailCore/MCOAbstractMultipart.h>

@class PSTMailAccount, WebView, MCOIMAPMessage;

@interface MCOAbstractPart (LEPRecursiveAttachments)

- (NSArray *)allAttachments;
- (NSArray *)plaintextTypeAttachments;
- (NSArray *)calendarTypeAttachments;
- (NSArray *)attachmentsWithContentIDs;

@end

@interface MCOAbstractPart (PSTMustacheRendering)

- (NSDictionary *)dmTemplateValuesWithAccount:(PSTMailAccount *)account;
- (void)dmPreviewString:(NSMutableString *)str account:(PSTMailAccount *)account webView:(WebView *)webView hideQuoted:(BOOL)hideQ message:(MCOIMAPMessage *)message withAttachments:(NSArray *)attachments printing:(BOOL)forPrinting;

@end

@interface MCOAbstractMultipart (LEPRecursiveAttachments)

- (NSArray *)allAttachments;
- (NSArray *)plaintextTypeAttachments;
- (NSArray *)calendarTypeAttachments;
- (NSArray *)attachmentsWithContentIDs;

@end