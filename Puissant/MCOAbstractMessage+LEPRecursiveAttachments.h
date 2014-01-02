//
//  MCOAbstractMessage+LEPRecursiveAttachments.h
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <MailCore/MCOAbstractMessage.h>

@interface MCOAbstractMessage (LEPRecursiveAttachments)

- (NSArray *)allAttachments;
- (NSArray *)plaintextTypeAttachments;
- (NSArray *)calendarTypeAttachments;
- (NSArray *)attachmentsWithContentIDs;

- (BOOL)isFacebookNotification;
- (BOOL)isTwitterNotification;

@end
