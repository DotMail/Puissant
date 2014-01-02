//
//  PSTConversationCache.h
//  DotMail
//
//  Created by Robert Widmann on 10/10/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/mailcore.h>

@class PSTCachedMessage, PSTSerializableMessage, PSTDatabase, RACSignal;

@interface PSTConversationCache : NSObject <NSCoding>

@property (nonatomic, weak) PSTDatabase *storage;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) NSArray *labels;
@property (nonatomic, strong) NSString *subject;
@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSString *previewPath;
@property (nonatomic, strong) NSString *previewMessageID;
@property (nonatomic, assign) uint32_t previewUID;
@property (nonatomic, assign) NSUInteger previewRowID;
@property (nonatomic, assign) PSTActionStepValue actionStep;
@property (nonatomic, assign) MCOMessageFlag flags;
@property (nonatomic, strong) NSArray *senders;
@property (nonatomic, strong) NSArray *recipients;
@property (nonatomic, copy, readonly) NSString *preview;

- (void)loadFromDatabase:(PSTDatabase *)database folderID:(NSUInteger)folderID otherFolderID:(NSUInteger)otherFolderID inboxFolderID:(NSUInteger)inboxFolderID draftsFolderID:(NSUInteger)draftsFolderID sentFolderID:(NSUInteger)sentFolderID;
- (void)resolveCachedSendersAndRecipients;

- (void)addLabels:(id)label;
- (void)removeLabel:(id)label;

- (void)removeMessageAtIndex:(NSUInteger)index;

- (BOOL)isMessageDraft:(MCOIMAPMessage *)message;

- (void)addMessageCache:(PSTCachedMessage *)cachedMessage;
- (void)addMessage:(PSTSerializableMessage *)cachedMessage rowID:(NSUInteger)rowID folderID:(NSUInteger)folderID;

- (void)clearMessages;

- (void)resolveDateUsingFolder:(NSUInteger)folderID;

- (RACSignal *)previewSignal;
- (void)loadPreviewSignals;
- (void)removeObserverForUID;

@end