//
//  CFIConversation.h
//  DotMail
//
//  Created by Robert Widmann on 8/8/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSTDatabaseController, PSTConversationCache, PSTMailAccount, MCOIMAPFolder, MCOIMAPMessage;

@interface PSTConversation : NSObject <NSCopying>

+ (NSUInteger)globalMessageCount;
+ (NSString *)emptyMessageHTML;

- (void)load;
- (void)loadCache;
- (PSTMailAccount *)account;
- (void)setNeedsReloadCache;
- (PSTConversation *)reloadedConversation;
- (NSArray *)labels;
- (NSString *)subject;
- (BOOL)hasPreview;
- (BOOL)isSeen;
- (void)updateCacheActionstepValue;
- (void)updateCacheFlags;
- (NSString *)htmlRenderingWithAccount:(PSTMailAccount *)account;
- (NSString *)htmlBodyValue;

@property (nonatomic, strong) PSTDatabaseController *storage;
@property (nonatomic, assign) PSTActionStepValue actionStep;
@property (nonatomic, strong) PSTConversationCache *cache;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSMutableArray *attachments;
@property (nonatomic, strong) MCOIMAPFolder *folder;
@property (nonatomic, strong) MCOIMAPFolder *otherFolder;
@property (nonatomic, assign) NSUInteger conversationID;
@property (nonatomic, strong) NSDate *sortDate;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy, readonly) NSString *preview;
@property (nonatomic, assign) BOOL draft;
@property (nonatomic, assign, getter = isImportant) BOOL important;
@property (nonatomic, assign) NSUInteger mode;
@property (nonatomic, strong, readonly) NSImage *iconImage;

@end