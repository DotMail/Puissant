//
//  PSTAccountChecker.h
//  Puissant
//
//  Created by Robert Widmann on 10/24/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/mailcore.h>

/**
 * An object which checks the validity of a set of email credentials, and tries multiple connections 
 * before returning an error.
 */

typedef NS_OPTIONS(int, PSTAccountCheckerMask) {
	PSTAccountCheckIMAP = 1 << 0,
	PSTAccountCheckPOP = 1 << 1,
	PSTAccountCheckSMTP = 1 << 2
};

@class MCONetService;
@class MCOMailProvider;
@class RACSignal;

@interface PSTAccountChecker : NSObject

@property (nonatomic, strong) MCOMailProvider *provider;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, strong, readonly) NSError *error;
@property (nonatomic, strong, readonly) NSError *authError;

@property (nonatomic, assign) PSTAccountCheckerMask checkerMask;

@property (nonatomic, assign) NSUInteger port;

@property (nonatomic, copy) NSString *imapHostname;
@property (nonatomic, assign) int imapPort;

@property (nonatomic, copy) NSString *popHostname;
@property (nonatomic, assign) int popPort;

@property (nonatomic, copy) NSString *smtpHostname;
@property (nonatomic, assign) int smtpPort;

@property (nonatomic, assign) MCOAuthType authType;

@property (nonatomic, strong) MCOIMAPSession *imap;
@property (nonatomic, strong) MCONetService *imapService;
@property (nonatomic, assign) int imapStep;
@property (nonatomic, strong) MCOIMAPOperation *imapRequest;

@property (nonatomic, strong) MCOSMTPSession *smtp;
@property (nonatomic, strong) MCONetService *smtpService;
@property (nonatomic, assign) int smtpStep;
@property (nonatomic, strong) MCOSMTPOperation *smtpRequest;

/// Standard initializer
- (id)init;

/**
 * Returns a signal that contains the results of the checking process.  Subscribe error for the 
 * overarching sync error; subscribe completed for a successful check.
 */
- (RACSignal *)check;

/**
 * Invalidates the checker and cancels all associated processes.
 */
- (void)cancel;

@end