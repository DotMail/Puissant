//
//  PSTAccountManager.m
//  DotMail
//
//  Created by Robert Widmann on 10/19/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTAccountManager.h"
#import "PSTMailAccount.h"
#import "NPReachability.h"

@interface PSTAccountManager ()

@property (nonatomic, strong) NSMutableArray *accounts;
@property (nonatomic, strong) NSMutableDictionary *accountHash;

@end

@implementation PSTAccountManager

#pragma mark - Lifecycle

+ (instancetype)defaultManager {
	PUISSANT_SINGLETON_DECL(PSTAccountManager);
}

- (id)init {
	self = [super init];
	
	_accounts = [[NSMutableArray alloc] init];
	_accountHash = [NSMutableDictionary dictionary];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_userDefaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];

	return self;
}

- (void)dealloc {
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Account Management

- (void)setAccounts:(NSMutableArray *)accounts {
	[self.accountHash removeAllObjects];
	[_accounts setArray:accounts];
	for (PSTMailAccount *account in self.accounts) {
		[self.accountHash setObject:account forKey:account.email];
	}
	[self notifyAccountsListChanged];
}

- (BOOL)addAccount:(PSTMailAccount *)account {
	if (self.accountHash[account.email]) return NO;
	[self.accounts addObject:account];
	[self.accountHash setObject:account forKey:account.email];
	[self notifyAccountsListChanged];
	return YES;
}

- (void)removeAccount:(PSTMailAccount *)account {
	[account remove];
	[self.accountHash removeObjectForKey:account.email];
	[self.accounts removeObject:account];
	[self notifyAccountsListChanged];
}

#pragma mark - Account Search

- (PSTMailAccount *)accountForEmail:(NSString *)email {
	return [self.accountHash objectForKey:email];
}

#pragma mark - Saving and Loading Accounts

- (void)synchronize {
	NSMutableArray *arrayOfAccounts = [NSMutableArray array];
	for (PSTMailAccount *account in self.accounts) {
		[arrayOfAccounts addObject:account.dictionaryValue];
	}
	[[NSUserDefaults standardUserDefaults] setObject:arrayOfAccounts forKey:@"Accounts"];
}

- (void)initializeAccounts {
	NSArray *defaultsAccounts = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Accounts"];
	for (NSDictionary *infoDictionary in defaultsAccounts) {
		PSTMailAccount *newAccount = [[PSTMailAccount alloc] initWithDictionary:infoDictionary];
		if (self.accountHash[newAccount.email]) continue;
		[self.accounts addObject:newAccount];
		[self.accountHash setObject:newAccount forKey:newAccount.email];
		[newAccount refreshSync];
	}
}

#pragma mark - Account Notifications

- (void)notifyAccountsListChanged {
	dispatch_async(dispatch_get_main_queue(), ^{
		[NSNotificationCenter.defaultCenter postNotificationName:PSTAccountManagerAccountListChangedNotification object:self];
	});
	PSTPropogateValueForKey(self.accounts, { });
	[self synchronize];
}

#pragma mark - Private

- (void)_userDefaultsChanged:(NSNotification *)notification { }

@end