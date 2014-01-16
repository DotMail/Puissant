//
//  PSTMailAccount.m
//  DotMail
//
//  Created by Robert Widmann on 9/8/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTMailAccount.h"
#import "PSTIMAPMailAccount.h"
#import "PSTPOPMailAccount.h"

NSString *const PSTDraftsFolderPathKey = @"PSTDraftsFolderPathKey";
NSString *const PSTSentMailFolderPathKey = @"PSTSentMailFolderPathKey";
NSString *const PSTImportantFolderPathKey = @"PSTImportantFolderPathKey";
NSString *const PSTSpamFolderPathKey = @"PSTSpamFolderPathKey";

@implementation PSTMailAccount

+ (NSString *)defaultHTMLSignatureSuffix { return nil; }
- (id)initWithDictionary:(NSDictionary *)dictionary {
	if (dictionary[@"PSTIMAPService"]){
		return self = [[PSTIMAPMailAccount alloc]initWithDictionary:dictionary];
	} else if (dictionary[@"PSTPOPService"]){
		return self = [[PSTPOPMailAccount alloc]initWithDictionary:dictionary];
	}
	
	[NSException raise:NSInvalidArgumentException format:@"Tried to initialize a %@ without a discernable service", NSStringFromClass(self.class)];
	return nil;
}

- (id)init {
	[NSException raise:NSInternalInconsistencyException format:@"Tried to initialize a %@ without a dictionary", NSStringFromClass(self.class)];
	return nil;
}

- (void)sync { }
- (void)refreshSync { }
- (RACSignal *)sendMessage:(id)message { return nil; }
- (RACSignal *)saveMessage:(id)message { return nil; }
- (NSDictionary *)info { return nil; }
- (MCOAddress *)addressValueWithName:(BOOL)name { return nil; }
- (void)setColor:(NSColor *)color forLabel:(NSString *)label { }
- (NSColor *)colorForLabel:(NSString *)label { return nil; }
- (NSDictionary *)folders { return nil; }
- (BOOL)hasDataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path { return NO; };
- (NSData *)dataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path { return nil; };
- (BOOL)hasDataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path { return NO; }
- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment onMessage:(MCOIMAPMessage *)message atPath:(NSString *)path { return nil; }
- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path { return nil; }
- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path { return nil; }
- (BOOL)isSelectionAvailable:(PSTFolderType)selection { return NO; }
- (NSUInteger)countForFolder:(PSTFolderType)folder{ return 0; }
- (NSUInteger)unreadCountForFolder:(PSTFolderType)folder { return 0; }
- (void)waitUntilAllOperationsHaveFinished { }
- (void)beginConversationUpdates { }
- (void)endConversationUpdates { }
- (void)addModifiedMessage:(MCOAbstractMessage *)message atPath:(NSString *)path { }
- (void)searchWithTerms:(NSArray *)terms complete:(BOOL)complete searchStringToComplete:(NSAttributedString *)attributedString { }
- (void)cancelSearch { }
- (NSArray *)searchSuggestions { return nil; }
- (NSArray *)allLabels { return nil; }
- (void)save { }
- (void)remove { }
- (NSArray *)visibleLabels { return nil; }
- (RACSignal *)facebookMessagesSignal { return nil; }
- (RACSignal *)twitterMessagesSignal { return nil; }
- (RACSignal *)attachmentsSignal { return nil; }
- (BOOL)loading { return NO; }
- (void)deleteConversation:(PSTConversation *)conversation { }
- (void)checkNotifications { }

@end