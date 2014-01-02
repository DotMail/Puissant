//
//  PSTPOPMailAccount.m
//  Puissant
//
//  Created by Robert Widmann on 5/14/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTPOPMailAccount.h"

@implementation PSTPOPMailAccount

//- (void)_setupSync {
//	[self _setupPopSync];
//	[self _setupSMTP];	/*Unsure about this*/
//	[self _updatePendingPassword];
//	if (_smtpService != nil) {
//		[self _setupSMTP];	/*Unsure about this*/
//		[self _updatePendingPassword];
//		return;
//	}
//}
//
//- (void)_setupPopSync {
//	if (_imapSynchronizer == nil) {
//		PSTPopAccountSynchronizer *popSynchronizer = [[PSTPopAccountSynchronizer alloc] init];
//		[popSynchronizer setEmail:self.email];
//		[popSynchronizer setHost:self.imapService.hostname];
//		[popSynchronizer setPassword:[FXKeychain.defaultKeychain objectForKey:self.email]];
//		[popSynchronizer setPort:self.imapService.port];
//		[popSynchronizer setAuthType:self.imapService.authType];
//		[popSynchronizer setKind:self.accountKind];
//		[popSynchronizer setProviderIdentifier:self.providerIdentifier];
//		[popSynchronizer setNamespacePrefix:self.namespacePrefix];
//		[popSynchronizer setXListMapping:self.xListMapping];
//		[popSynchronizer setInboxRefreshDelay:self.inboxRefreshDelay];
//		
//		[popSynchronizer addObserver:self forKeyPath:@"error" options:0 context:nil];
//		[popSynchronizer addObserver:self forKeyPath:@"loading" options:0 context:nil];
//		[popSynchronizer addObserver:self forKeyPath:@"committing" options:0 context:nil];
//		[popSynchronizer addObserver:self forKeyPath:@"savingAttachment" options:0 context:nil];
//		[popSynchronizer addObserver:self forKeyPath:@"syncing" options:0 context:nil];
//		[popSynchronizer addObserver:self forKeyPath:@"currentConversations" options:0 context:nil];
//		[popSynchronizer setDelegate:self];
//		
//		_imapSynchronizer = popSynchronizer;
//	}
//}

@end
