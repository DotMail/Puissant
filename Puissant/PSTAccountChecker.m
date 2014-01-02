//
//  PSTAccountChecker.m
//  Puissant
//
//  Created by Robert Widmann on 10/24/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTAccountChecker.h"
#import <ReactiveCocoa/EXTScope.h>
#import <MailCore/MailCore.h>

@interface PSTAccountChecker ()

@property (nonatomic, strong) NSError *authError;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) BOOL security;
@property (nonatomic, strong) NSMutableArray *requests;
@property (nonatomic, strong) RACDisposable *currentDisposable;

@end

@implementation PSTAccountChecker 

static RACScheduler *checkScheduler() {
	static RACScheduler *syncScheduler = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		syncScheduler = [RACScheduler scheduler];
	});
	return syncScheduler;
}

// Returns the current scheduler
static RACScheduler *currentScheduler() {
	NSCAssert(RACScheduler.currentScheduler != nil, @"KrakenKit called from a thread without a RACScheduler.");
	return RACScheduler.currentScheduler;
}

- (id)init
{
	if (self = [super init]) {
		self.checkerMask = (PSTAccountCheckIMAP | PSTAccountCheckSMTP);
		self.requests = [NSMutableArray array];
	}
	return self;
}

- (void)dealloc {
	[self.imapRequest cancel];
	self.imapRequest = nil;
	[self.smtpRequest cancel];
	self.smtpRequest = nil;
}

- (RACSignal*)check;
{
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		return [[RACScheduler scheduler]schedule:^{
			@weakify(self);
			self.currentDisposable = [[self _checkImap]
			 subscribeError:^(NSError *error) {
				 @strongify(self);
				 [subscriber sendError:error];
				 [self cancel];
			 } completed:^{
				[subscriber sendCompleted];
			}];
		}];
	}];
}

- (BOOL)_isIMAP {
	BOOL result = NO;
	if (self.checkerMask & PSTAccountCheckIMAP) {
		result = ([self _providerForIMAP].imapServices.count != 0 ? YES : NO);
	}
	return result;
}

- (BOOL)_isPOP {
	BOOL result = NO;
	if (self.checkerMask & PSTAccountCheckPOP) {
		result = ([self _providerForPOP].imapServices.count != 0 ? YES : NO);
	}
	return result;
}

- (MCOMailProvider *)_provider {
	MCOMailProvider *result = nil;
	if (self.provider != nil) {
		return self.provider;
	}
	result = [[MCOMailProvidersManager sharedManager] providerForEmail:self.email];
	if (result == nil) {
		result = [[MCOMailProvidersManager sharedManager] providerForIdentifier:@"gmail"];
	}
	return result;
}

- (MCOMailProvider *)_providerForIMAP {
	MCOMailProvider *result = nil;
	if (self.security != NO) {
		if (self.imapPort != 1) {
			if (self.imapHostname == nil) {
				return [self _provider];
			}
			result = [[MCOMailProvidersManager sharedManager] providerForIdentifier:self.imapHostname];
		}
		result = [[MCOMailProvidersManager sharedManager] providerForIdentifier:self.imapHostname];
	}
	if (self.imapHostname == nil) {
		return [self _provider];
	}
	return result;
}

- (MCOMailProvider *)_providerForPOP {
	MCOMailProvider *result = nil;
	if (self.security != NO) {
		if (self.popPort != 1) {
			if (self.popHostname == nil) {
				return [self _provider];
			}
			result = [[MCOMailProvidersManager sharedManager] providerForIdentifier:self.popHostname];
		}
		result = [[MCOMailProvidersManager sharedManager] providerForIdentifier:self.popHostname];
	}
	if (self.popHostname == nil) {
		return [self _provider];
	}
	return result;
}

- (MCOMailProvider *)_providerForSMTP {
	MCOMailProvider *result = nil;
	if (self.security != NO) {
		if (self.smtpPort != 1) {
			if (self.smtpHostname == nil) {
				return [self _provider];
			}
			result = [[MCOMailProvidersManager sharedManager] providerForIdentifier:self.smtpHostname];
		}
		result = [[MCOMailProvidersManager sharedManager] providerForIdentifier:self.smtpHostname];
	}
	if (self.smtpHostname == nil) {
		return [self _provider];
	}
	return result;
}

- (RACSignal*)_checkImap
{
	return [RACSignal createSignal: ^RACDisposable * (id < RACSubscriber > subscriber) {
		return [checkScheduler () schedule: ^{
			if (self.checkerMask & PSTAccountCheckIMAP) {
				if ([self _providerForIMAP].imapServices.count == 0) {
					self.error = [[NSError alloc] initWithDomain:PSTErrorDomain code:0x5 userInfo:nil];
					[subscriber sendCompleted];
					return;
				}
				self.imapStep = 0;
				[self _checkImapStepWithSubscriber:subscriber];
			}
		}];
	}];
}

- (void)_checkImapStepWithSubscriber:(id < RACSubscriber >)subscriber
{
	MCOMailProvider *imapProvider = [self _providerForIMAP];
	if (self.imapStep < imapProvider.imapServices.count) {
		MCONetService *imapService = [imapProvider.imapServices objectAtIndex:self.imapStep];
		self.imap = [[MCOIMAPSession alloc] init];
		[self.imap setCheckCertificateEnabled:NO];
		if (self.imapHostname != nil) {
			[self.imap setHostname:self.imapHostname];
		}
		else {
			[self.imap setHostname:[imapService hostnameWithEmail:self.email]];
		}
		if (self.imapPort != 0) {
			[self.imap setPort:self.imapPort];
		}
		else {
			[self.imap setPort:imapService.port];
		}
		[self.imap setUsername:self.email];
		[self.imap setPassword:self.password];
		[self.imap setConnectionType:imapService.connectionType];
		
		@weakify(self);
		[self.imap.checkAccountOperation start:^(NSError *error) {
			@strongify(self);
			if (error) {
				if ([error.domain isEqualToString:MCOErrorDomain] && error.code == MCOErrorAuthentication) {
					self.authError = [error copy];
				}
				[subscriber sendError:error];
				self.imapStep += 1;
				[self _checkImapStepWithSubscriber:subscriber];
				return;
			}
			self.authError = nil;
			MCONetService *candidateService = [[[self _providerForIMAP] imapServices] objectAtIndex:self.imapStep];
			if (self.imapHostname != nil) {
				self.imapService = [candidateService copy];
				[self.imapService setHostname:self.imapHostname];
				if (self.imapPort != 0) {
					[self.imapService setPort:self.imapPort];
				}
			}
			else {
				self.imapService = [candidateService copy];
				[self.imapService setHostname:[self.imapService hostnameWithEmail:self.email]];
			}
			[self.imapService setConnectionType:self.imapService.connectionType];
			self.error = nil;
			[subscriber sendCompleted];
		}];
	} else {
		[subscriber sendCompleted];
	}
}

- (RACSignal*)_checkSmtp
{	
	@weakify(self);
	return [RACSignal createSignal: ^RACDisposable * (id <RACSubscriber> subscriber) {
		return [checkScheduler () schedule: ^{
			@strongify(self);
			if (self.checkerMask & PSTAccountCheckSMTP) {
				if ([self _providerForSMTP].smtpServices.count == 0) {
					self.error = [[NSError alloc] initWithDomain:PSTErrorDomain code:0x7 userInfo:nil];
					[subscriber sendCompleted];
					return;
				}
				self.imapStep = 0;
				self.smtpStep = 0;
				[self _checkSmtpStepWithSubscriber:subscriber];
			}
		}];
	}];
}

- (void)_checkSmtpStepWithSubscriber:(id < RACSubscriber >)subscriber
{
	MCOMailProvider *smtpProvider = [self _providerForSMTP];
	if (self.smtpStep < smtpProvider.smtpServices.count) {
		MCONetService *smtpService = [smtpProvider.smtpServices objectAtIndex:self.smtpStep];
		self.smtp = [[MCOSMTPSession alloc] init];
		[self.smtp setCheckCertificateEnabled:NO];
		if (self.smtpHostname != nil) {
			[self.smtp setHostname:self.smtpHostname];
		}
		else {
			[self.smtp setHostname:[smtpService hostnameWithEmail:self.email]];
		}
		if (self.smtpPort != 0) {
			[self.smtp setPort:self.smtpPort];
		}
		else {
			[self.smtp setPort:smtpService.port];
		}
		[self.smtp setUsername:self.email];
		[self.smtp setPassword:self.password];
		[self.smtp setConnectionType:smtpService.connectionType];
		
		@weakify(self);
		[[self.smtp checkAccountOperationWithFrom:[MCOAddress addressWithMailbox:self.email]]start:^(NSError *error) {
			@strongify(self);
			if (error) {
				if ([error.domain isEqualToString:MCOErrorDomain] && error.code == MCOErrorAuthentication) {
					self.authError = [error copy];
				}
				[subscriber sendError:error];
				self.smtpStep += 1;
				[self _checkSmtpStepWithSubscriber:subscriber];
				return;
			}
			self.authError = nil;
			MCONetService *candidateService = [[[self _providerForSMTP] smtpServices] objectAtIndex:self.smtpStep];
			if (self.smtpHostname != nil) {
				self.smtpService = [candidateService copy];
				[self.smtpService setHostname:self.imapHostname];
				if (self.smtpPort != 0) {
					[self.smtpService setPort:self.smtpPort];
				}
			}
			else {
				self.smtpService = [candidateService copy];
				[self.smtpService setHostname:[self.smtpService hostnameWithEmail:self.email]];
			}
			self.error = nil;
			[subscriber sendCompleted];
		}];
	}
	else {
		[subscriber sendCompleted];
	}
}

- (void)cancel {
	if (self.imapRequest != nil) {
		[self.imapRequest cancel];
		self.imapRequest = nil;
		self.imap = nil;
	}
	if (self.smtpRequest != nil) {
		[self.smtpRequest cancel];
		self.smtpRequest = nil;
		self.smtp = nil;
	}
}

@end