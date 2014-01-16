//
//  PSTSerializableMessage.h
//  Puissant
//
//  Created by Robert Widmann on 6/29/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <MailCore/mailcore.h>

@class PSTSerializablePart, PSTAccountController, PSTMailAccount, WebView;

@interface PSTSerializableMessage : MCOAbstractMessage <NSCoding>

@property (nonatomic, strong, readonly) NSDate *date;
@property (nonatomic, strong, readonly) NSDate *internalDate;
@property (nonatomic, strong, readonly) MCOAddress *sender;
@property (nonatomic, strong, readonly) MCOAddress *from;
@property (nonatomic, strong, readonly) NSMutableArray *recipients;
@property (nonatomic, copy, readonly) NSString *messageID;
@property (nonatomic, copy, readonly) NSString *subject;
@property (nonatomic, assign, readonly) NSUInteger folderID;
@property (nonatomic, assign, readonly) NSUInteger rowID;
@property (nonatomic, assign, readonly) uint32_t uid;
@property (nonatomic, assign) MCOMessageFlag flags;
@property (nonatomic, assign) MCOMessageFlag originalFlags;
@property (nonatomic, strong, readonly) NSArray *mainParts;
@property (nonatomic, strong, readonly) NSArray *attachments;
@property (nonatomic, strong, readonly) NSArray *references;
@property (nonatomic, strong, readonly) NSArray *inReplyTo;

+ (instancetype)serializableMessageWithMessage:(MCOAbstractMessage *)message;
- (id)initWithMessage:(MCOAbstractMessage *)message;

- (NSString *)uniqueMessageIdentifer;

- (NSDictionary *)templateValuesWithAccount:(PSTMailAccount *)account withUUID:(NSString *)uuid;
- (NSString *)bodyHTMLRenderingWithAccount:(PSTMailAccount *)account withWebView:(WebView *)webview;
@end
