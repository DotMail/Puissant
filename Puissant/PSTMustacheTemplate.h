//
//  PSTMoustacheTemplate.h
//  Puissant
//
//  Created by Robert Widmann on 1/2/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSTDatabaseController;

PUISSANT_EXPORT NSString *const PSTMoustacheConversationSubjectKey;
PUISSANT_EXPORT NSString *const PSTMoustachConversationsSendersKey;
PUISSANT_EXPORT NSString *const PSTMoustachConversationsOurEmailKey;
PUISSANT_EXPORT NSString *const PSTMoustachConversationsIsCCKey;
PUISSANT_EXPORT NSString *const PSTMoustachConversationsNumberCCdKey;
PUISSANT_EXPORT NSString *const PSTMoustachConversationsTimestampKey;
PUISSANT_EXPORT NSString *const PSTMoustachConversationsDateKey;
PUISSANT_EXPORT NSString *const PSTMoustachConversationsBodyHTML;
PUISSANT_EXPORT NSString *const PSTMoustacheConversationImageKey;
PUISSANT_EXPORT NSString *const PSTMoustacheConversationActionStepColorKey;

@interface PSTMustacheTemplate : NSObject

- (id)initWithFilename:(NSString *)filename inFolder:(NSString *)folder values:(NSDictionary*)values;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) PSTDatabaseController *database;

- (NSString*)render;

@end
