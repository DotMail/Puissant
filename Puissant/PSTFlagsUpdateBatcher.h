//
//  PSTFlagsUpdateBatcher.h
//  Puissant
//
//  Created by Robert Widmann on 11/20/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/mailcore.h>

@class PSTDatabaseController;

@interface PSTFlagsUpdateBatcher : NSObject

@property (nonatomic, strong) MCOIMAPFolder *folder;
@property (nonatomic, strong) PSTDatabaseController *storage;

@property (nonatomic, assign) BOOL hadChanges;
@property (nonatomic, assign) BOOL hadDeletedFlags;

@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSMutableArray *messagesFlags;


- (void)start;
- (void)startRequestWithCompletion:(void(^)())completionBlock;

@end
