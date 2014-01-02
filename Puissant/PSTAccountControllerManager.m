//
//  PSTAccountControllerManager.m
//  DotMail
//
//  Created by Robert Widmann on 10/9/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTAccountControllerManager.h"
#import "PSTAccountController.h"
#import "PSTMailAccount.h"
#import "PSTAccountManager.h"

@implementation PSTAccountControllerManager {
	NSMutableArray *_backingAccounts;
}

#pragma mark - Lifecycle

+ (instancetype) defaultManager {
	PUISSANT_SINGLETON_DECL(PSTAccountControllerManager);
}

- (id)init {
	self = [super init];
	
	_backingAccounts = [[NSMutableArray alloc] init];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_updateAccounts) name:PSTAccountManagerAccountListChangedNotification object:PSTAccountManager.defaultManager];
	[self _updateAccounts];
	
	return self;
}

- (NSArray *)accounts {
	return _backingAccounts;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	[self _updateAccounts];
}

#pragma mark - Search

- (PSTAccountController *)accountControllerForEmail:(NSString *)email {	
	for (PSTAccountController *unifiedAccount in _backingAccounts) {
		for (PSTMailAccount *account in unifiedAccount.accounts) {
			if ([account.email isEqualToString:email]) {
				return unifiedAccount;
			}
		}
	}
	return nil;
}

- (PSTAccountController *)accountControllerForAccount:(PSTMailAccount *)account {
	for (PSTAccountController *unifiedAccount in _backingAccounts) {
		if ([unifiedAccount.accounts containsObject:account]) {
			return unifiedAccount;
		}
	}
	return nil;
}

- (NSArray *)accountsForEmail:(NSString *)email {
	NSMutableArray *retVal = @[].mutableCopy;
	
	for (PSTAccountController *unifiedAccount in _backingAccounts) {
		for (PSTMailAccount *account in unifiedAccount.accounts) {
			if ([account.email isEqualToString:email]) {
				[retVal addObject:unifiedAccount];
			}
		}
	}
	return retVal;
}

#pragma mark - Private

- (void)_updateAccounts {
	PSTPropogateValueForKey(self.accounts, {
		[_backingAccounts removeAllObjects];
		if (PSTAccountManager.defaultManager.accounts.count == 0) {
			[NSNotificationCenter.defaultCenter postNotificationName:PSTAccountControllerManagerAccountListChangedNotification object:self userInfo:nil];
		}
		else {
			if ([NSUserDefaults.standardUserDefaults boolForKey:PSTUnifiedInboxEnabled] == YES) {
				if (PSTAccountManager.defaultManager.accounts.count >= 2) {
					PSTAccountController *unifiedAccount = [[PSTAccountController alloc] initWithAccounts:PSTAccountManager.defaultManager.accounts.copy];
					[_backingAccounts addObject:unifiedAccount];
				}
			}
			for (PSTMailAccount *mailAccount in PSTAccountManager.defaultManager.accounts) {
				PSTAccountController *unifiedAccount = [[PSTAccountController alloc] initWithAccount:mailAccount];
				[_backingAccounts addObject:unifiedAccount];
			}
			[NSNotificationCenter.defaultCenter postNotificationName:PSTAccountControllerManagerAccountListChangedNotification object:self userInfo:nil];
		}
	});
}

@end
