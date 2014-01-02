//
//  PSTSerializablePart.h
//  Puissant
//
//  Created by Robert Widmann on 6/30/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <MailCore/mailcore.h>

@class PSTMailAccount;

@interface PSTSerializablePart : NSObject <NSCoding>

+ (instancetype)serializablePartWithPart:(MCOIMAPPart *)part;

@property (nonatomic, copy) NSString *partID;
@property (nonatomic, nonatomic) unsigned int size;
@property (nonatomic, nonatomic) MCOEncoding encoding;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *mimeType;

- (NSArray *)plaintextTypeAttachments;

- (NSDictionary *)templateValuesWithAccount:(PSTMailAccount *)account;

@end
