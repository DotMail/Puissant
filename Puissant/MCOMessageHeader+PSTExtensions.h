//
//  MCOMessageHeader+PSTExtensions.h
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <MailCore/MCOMessageHeader.h>

@class PSTMailAccount;

@interface MCOMessageHeader (PSTExtensions)  <NSCoding>

- (NSString *)uniqueMessageIdentifer;

@end

@interface MCOMessageHeader (PSTTemplateRendering)

- (NSDictionary *)dmTemplateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)uuid withColorMapping:(id)mapping isDraft:(BOOL)isDraft attachments:(NSArray *)attachments attachmentsWithContentIDs:(NSArray *)attsWithContentIDs;
- (NSMutableDictionary *)dmMutableTemplateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)uuid withColorMapping:(id)mapping isDraft:(BOOL)isDraft attachments:(NSArray *)attachments attachmentsWithContentIDs:(NSArray *)attsWithContentIDs;

@end
