//
//  CFIConversation.m
//  DotMail
//
//  Created by Robert Widmann on 8/8/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTAccountManager.h"
#import "PSTMailAccount.h"
#import "PSTConversation.h"
#import "PSTConversationCache.h"
#import "PSTDatabaseController+Operations.h"
#import <MailCore/mailcore.h>
#import "PSTMustacheTemplate.h"
#import "MCOAddress+PSTPrettification.h"
#import "NSDate+Helper.h"
#import "PSTUpdateActionstepsOperation.h"
#import "PSTAvatarImageManager.h"
#import "PSTCachedMessage.h"
#import "NSImage+PSTBase64.h"
#import "NSString+HTML.h"
#import "GTMNSString+HTML.h"
#import "PSTSerializableMessage.h"
#import "MCOIMAPMessage+PSTExtensions.h"
#import "PSTAccountController.h"

static NSUInteger globalMessageCount;
static NSString *PSTConversationJSURL = nil;
static NSString *PSTConversationCSSURL = nil;
static NSString *PSTComposerJSURL = nil;
static NSString *PSTComposerCSSURL = nil;

@interface PSTConversation ()

@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL needsReloadCache;
@property (nonatomic, assign) NSTimeInterval delayedReloadCacheDate;
@property (nonatomic, copy) NSString *preview;

@end

@implementation PSTConversation

+ (void)initialize {
	if (self.class == PSTConversation.class) {
		NSString *conversationJSPath = [NSBundle.mainBundle pathForResource:@"conversation" ofType:@"js"];
		if (conversationJSPath) {
			PSTConversationJSURL = [[NSURL fileURLWithPath:[NSBundle.mainBundle pathForResource:@"conversation" ofType:@"js"]] absoluteString];
		}
		NSString *conversationCSSPath = [NSBundle.mainBundle pathForResource:@"conversation" ofType:@"css"];
		if (conversationCSSPath) {
			PSTConversationCSSURL = [[NSURL fileURLWithPath:[NSBundle.mainBundle pathForResource:@"conversation" ofType:@"css"]] absoluteString];
		}
		NSString *composerJSPath = [NSBundle.mainBundle pathForResource:@"composer" ofType:@"css"];
		if (composerJSPath) {
			PSTComposerJSURL = [[NSURL fileURLWithPath:[NSBundle.mainBundle pathForResource:@"composer" ofType:@"js"]] absoluteString];
		}
		NSString *composerCSSPath = [NSBundle.mainBundle pathForResource:@"composer" ofType:@"css"];
		if (composerCSSPath) {
			PSTComposerCSSURL = [[NSURL fileURLWithPath:[NSBundle.mainBundle pathForResource:@"composer" ofType:@"css"]] absoluteString];
		}
	}
}

+ (NSUInteger)globalMessageCount {
	return globalMessageCount;
}

+ (NSString *)emptyMessageHTML {
	return [[[PSTMustacheTemplate alloc] initWithFilename:@"new_message" inFolder:@"" values:@{ @"COMPOSER_COMPILED_JS_URL" : PSTComposerJSURL,
																							   @"MESSAGE_EDITING_CSS_URL" : PSTComposerCSSURL,
																							 }] render];
}

- (id)init {
	if (self = [super init]) {
		globalMessageCount += 1;
	}
	return self;
}
- (void)dealloc {
	globalMessageCount -= 1;
}

- (id)copyWithZone:(NSZone *)zone {
	PSTConversation *copiedConversation = [[PSTConversation alloc]init];
	[copiedConversation setSortDate:self.sortDate];
	[copiedConversation setConversationID:self.conversationID];
	[copiedConversation setFolder:self.folder];
	[copiedConversation setOtherFolder:self.otherFolder];
	[copiedConversation setStorage:self.storage];
	[copiedConversation setMode:self.mode];
	[copiedConversation setActionStep:self.actionStep];
	return copiedConversation;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@:%p %lu %@ - %@ - %i>", [self class], self, [self conversationID], [self subject], [self sortDate], self.actionStep];
}

- (NSString *)htmlBodyValue {
	NSMutableString *html = @"".mutableCopy;
	for (PSTCachedMessage *message in self.messages) {
		char *cStr = (char *)[self.storage dataForAttachment:PSTPreferredIMAPPart(message.mainParts) onMessage:(MCOAbstractMessage *)message atPath:self.folder.path ?: message.folder].bytes;
		if (cStr == NULL) continue;
		NSString *rendering = [NSString stringWithCString:cStr encoding:NSUTF8StringEncoding];
		if (rendering.length == 0) {
			rendering = [NSString stringWithCString:cStr encoding:NSASCIIStringEncoding];
		}
		if (rendering.length) [html appendString:[rendering mco_cleanedHTMLString]];
	}
	return [html gtm_stringByEscapingForHTML];
}

- (NSString *)htmlRenderingWithAccount:(PSTMailAccount*)account{
	PSTMustacheTemplate *moustacheTemplate = [[PSTMustacheTemplate alloc]initWithFilename:@"conversation" inFolder:self.folder.path values:[self templateValuesWithAccount:account fromOlderToNewer:YES]];
	moustacheTemplate.database = self.storage;
	moustacheTemplate.messages = self.cache.messages;
	return [moustacheTemplate render];
}

- (NSDictionary *)templateValuesWithAccount:(PSTMailAccount *)account fromOlderToNewer:(BOOL)olderNewer {
	int index = 0;
	return [self templateValuesWithAccount:account fromOlderToNewer:olderNewer colorMapping:nil colorIndex:&index];
}

- (NSDictionary *)templateValuesWithAccount:(PSTMailAccount *)account fromOlderToNewer:(BOOL)olderNewer colorMapping:(id)mapping colorIndex:(int *)outIndex {
	PSTMailAccount *mainAccount = (PSTMailAccount *)account;
	if ([account respondsToSelector:@selector(mainAccount)]) {
		mainAccount = ((PSTAccountController *)account).mainAccount;
	}
	
	MCOAddress *firstAddress = [self.cache.senders lastObject];
	NSString *addressString = @"";
	if (firstAddress.dm_prettifiedDisplayString != nil) {
		addressString = firstAddress.dm_prettifiedDisplayString;
	}
	BOOL ccd = self.cache.recipients.count > 1;
	NSArray *ccArray = @[];
	if (ccd) {
		ccArray = @[@{PSTMoustachConversationsNumberCCdKey : @(self.cache.recipients.count)}];
	}

	NSString *ourEmail = @"me";
	if (self.cache.recipients.count != 0 && [self.cache.recipients indexOfObject:[account addressValueWithName:YES]] == NSNotFound && [self.cache.recipients indexOfObject:[account addressValueWithName:NO]] == NSNotFound) {
		ourEmail = [self.cache.recipients[0] dm_prettifiedDisplayString];
	}

	NSMutableDictionary *values = @{PSTMoustacheConversationSubjectKey : self.subject,
							 PSTMoustachConversationsSendersKey : addressString,
							 PSTMoustachConversationsOurEmailKey : ourEmail,
							 PSTMoustachConversationsIsCCKey : ccArray,
							 PSTMoustachConversationsDateKey : [self.sortDate dmDotFormattedDateString],
							 PSTMoustachConversationsTimestampKey : [self.sortDate dmTimeFormattedDateString],
							 PSTMoustacheConversationImageKey : [PSTAvatarImageManager.defaultManager avatarForEmail:[self.cache.senders[0] mailbox]].base64Representation,
							 PSTMoustacheConversationActionStepColorKey : PSTHexValueForActionstep(self.actionStep),
							 @"CONVERSATION_COMPILED_JS_URL" : PSTConversationJSURL,
							 @"CONVERSATION_CSS_URL" : PSTConversationCSSURL,
							 }.mutableCopy;

	NSMutableArray *messagesRenderings = @[].mutableCopy;
	for (int i = 0; i < self.messages.count; i++) {
		PSTSerializableMessage *message = self.messages[i];
		NSMutableDictionary *templateValues = [message templateValuesWithAccount:account withUUID:message.uniqueMessageIdentifer].mutableCopy;
		if (i == 0) {
			[templateValues setObject:@{} forKey:@"IS_FIRST_MESSAGE"];
		}
		if (templateValues) {
			PSTMustacheTemplate *messageTemplate = [[PSTMustacheTemplate alloc] initWithFilename:@"message_template" inFolder:[message dm_folder].path values:templateValues];
			[messagesRenderings addObject:messageTemplate.render.stringByDecodingHTMLEntities];
		}
	}
	[values setObject:messagesRenderings forKey:PSTMoustachConversationsBodyHTML];

	return values;
}


- (NSImage *)iconImage {
	return [PSTAvatarImageManager.defaultManager avatarForEmail:[self.cache.senders[0] mailbox]];
}

- (BOOL)hasPreview {
	return self.preview != nil && ![self.preview isEqualToString:@""];
}

- (NSMutableArray *)attachments {
	NSMutableArray *result = [[NSMutableArray alloc]init];
	for (MCOIMAPMessage *message in self.messages) {
		[result addObjectsFromArray:[message attachments]];
	}
	return result;
}

- (NSComparisonResult)compare:(id)otherObject {
	return [[(PSTConversation *)otherObject sortDate] compare:self.sortDate];
}

- (NSComparisonResult)compareWithActionSteps:(id)otherObject {
	if ([self actionStep] > [otherObject actionStep]) {
		return (NSComparisonResult)NSOrderedAscending;
	} else if([self actionStep] < [otherObject actionStep]) {
		return (NSComparisonResult)NSOrderedDescending;
	}
	return [[(PSTConversation *)otherObject sortDate] compare:self.sortDate];
}

- (BOOL)isEqual:(id)object {
	BOOL retVal = NO;
	if ([object isKindOfClass:[PSTConversation class]]) {
		if ([(PSTConversation *)object conversationID] == self.conversationID) {
			retVal = [self.storage.email isEqualToString:[(PSTConversation *)object storage].email];
		}
	}
	return retVal;
}

- (void)updateCacheFlags {
	if (self.messages != nil) {
		MCOIMAPMessage *message = [self.messages lastObject];
		PSTPropogateValueForKey(self.cache, {
			[self.cache setFlags:message.flags];
		});
	}
}

- (PSTConversation *)reloadedConversation {
	PSTConversation *reloadedConversation = [[PSTConversation alloc]init];
	[reloadedConversation setSortDate:self.sortDate];
	[reloadedConversation setConversationID:self.conversationID];
	[reloadedConversation setFolder:self.folder];
	[reloadedConversation setOtherFolder:self.otherFolder];
	[reloadedConversation setStorage:self.storage];
	[reloadedConversation setMode:self.mode];
	[reloadedConversation setActionStep:self.actionStep];
	return reloadedConversation;
}

- (PSTMailAccount *)account {
	return [PSTAccountManager.defaultManager accountForEmail:self.storage.email];
}

- (NSString *)subject {
	if ([self.cache subject] == nil) {
		return @"(No subject)";
	}
	return [self.cache subject];
}

- (void)updateCacheActionstepValue {
	[self.cache setActionStep:self.actionStep];
	[[self.storage updateActionStepForConversation:self actionStep:self.actionStep] startRequest];
}

- (BOOL)hasPendingSendMessages:(id)messages {
	//	[self.storage hasPendingSendMessages:messages]
	return NO;
}

- (BOOL)isMessageDraft:(MCOIMAPMessage *)message {
	return [self.cache isMessageDraft:message];
}

- (BOOL)isSeen {
	return (self.cache.flags & MCOMessageFlagSeen);
}

- (NSDictionary *)_foldersDictionary {
	return [PSTAccountManager.defaultManager accountForEmail:self.storage.email].folders;
}

- (NSString *)draftsFolderPath {
	return [PSTAccountManager.defaultManager accountForEmail:self.storage.email].folders[PSTDraftsFolderPathKey];
}

- (NSString *)sentMailFolderPath {
	return [PSTAccountManager.defaultManager accountForEmail:self.storage.email].folders[PSTSentMailFolderPathKey];
}

- (NSString *)_importantFolderPath {
	return [PSTAccountManager.defaultManager accountForEmail:self.storage.email].folders[PSTImportantFolderPathKey];
}

- (NSArray *)labels {
	return self.cache.labels;
}

- (void)load {
	[self _loadWithForce:NO loadCache:YES];
}

- (void)_loadWithForce:(BOOL)force loadCache:(BOOL)loadCache {
	if ((force == NO) && ((self.messages != nil) || (self.loaded))) return;
	
	if (loadCache == YES) {
		[self loadCache];
	}
	self.loaded = YES;
	self.messages = nil;
	
	if (self.mode > 0x5) {
		self.messages = [NSArray array];
		PSTLog(@"other conversation mode %lu", (unsigned long)self.mode);
	}
	self.messages = [self.storage messagesForConversationID:self.conversationID mainFolder:self.folder folders:[self _foldersDictionary] draftsFolderPath:[self draftsFolderPath] sentMailFolderPath:[self sentMailFolderPath]];
	
	if (self.messages == nil) {
		self.messages = [NSArray array];
	}
	if (self.messages.count == 0) {
		PSTLog(@"empty conversation %@ %lu %lu %@ %@", self, (unsigned long)self.conversationID, (unsigned long)self.mode, self.folder, self.otherFolder);
	}
	if (self.messages.count > 1) {
		
	}
}

- (void)loadCache {
	if (self.needsReloadCache == NO && self.cache != nil) return;
	
	if (self.cache != nil) {
		if (PSTDefaultRefreshTimeInterval > [NSDate timeIntervalSinceReferenceDate] - self.delayedReloadCacheDate) return;
	}
	self.needsReloadCache = NO;
	self.cache = PSTConversationCacheForConversation(self, self.storage);
	self.sortDate = self.cache.date;
	//	RAC(self.preview) = RACAbleWithStart(cache.preview);
	if (self.cache != nil) {
		if ([self.cache count] == 0) {
			PSTLog(@"empty conversation cache %@", self);
			return;
		}
	}
	if (self.loaded == NO) {
		return;
	}
	else {
		[self _loadWithForce:YES loadCache:NO];
	}
}


- (void)setNeedsReloadCache {
	self.needsReloadCache = YES;
}

- (void)_unload {
	self.messages = nil;
	self.loaded = NO;
}

static NSString *PSTHexValueForActionstep(PSTActionStepValue actionStep) {
	switch (actionStep) {
		case PSTActionStepValueHigh:
			return @"#A0A0A0";
			break;
		case PSTActionStepValueMedium:
			return @"#A0A0A0";
			break;
		case PSTActionStepValueLow:
			return @"#A0A0A0";
			break;
		default:
			return @"#A0A0A0";
			break;
	}
	return @"";
}

#pragma mark - NSObject

- (NSUInteger)hash {
	return self.storage.email.hash ^ self.conversationID;
}

@end
