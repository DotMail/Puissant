//
//  PSTMoustacheTemplate.m
//  Puissant
//
//  Created by Robert Widmann on 1/2/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTMustacheTemplate.h"
#import "NSString+HTML.h"
#import "PSTDatabaseController.h"
#import "PSTCachedMessage.h"
#import "PSTSerializablePart.h"
#import <MailCore/mailcore.h>

NSString *const PSTMoustacheConversationSubjectKey = @"CONVERSATION_SUBJECT";
NSString *const PSTMoustachConversationsSendersKey = @"SENDERS_NAMES";
NSString *const PSTMoustachConversationsOurEmailKey = @"OUR_EMAIL";
NSString *const PSTMoustachConversationsIsCCKey = @"CCD_TO_OTHERS";
NSString *const PSTMoustachConversationsNumberCCdKey = @"NUMBER_CCD_TO";
NSString *const PSTMoustachConversationsTimestampKey = @"MAIN_MSG_TIME";
NSString *const PSTMoustachConversationsDateKey = @"MAIN_MSG_DATE";
NSString *const PSTMoustachConversationsBodyHTML = @"OTHER_CONVERSATION_MESSAGES";
NSString *const PSTMoustacheConversationImageKey = @"BASE_64_IMAGE_DATA";
NSString *const PSTMoustacheConversationActionStepColorKey = @"NEXT_STEP_COLOR";

@interface PSTMustacheTemplate ()

@property (nonatomic, strong) NSMutableDictionary *valuesDictionary;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *folder;

@end

@implementation PSTMustacheTemplate

- (id)initWithFilename:(NSString *)filename inFolder:(NSString *)folder values:(NSDictionary *)values {
	self = [super init];
	
	_valuesDictionary = [NSMutableDictionary dictionaryWithDictionary:values];
	_filename = filename;
	_folder = folder;
	
	return self;
}

- (NSString *)render {
	return @"";
//	return [rendering stringByDecodingHTMLEntities];
}

@end
