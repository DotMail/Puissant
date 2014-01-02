//
//  PSTAddressBookManager.m
//  Puissant
//
//  Created by Robert Widmann on 4/6/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTAddressBookManager.h"
#import <AddressBook/AddressBook.h>
#import "ABPerson+CFIAdditions.h"
#import "NSString+WhitespaceStripping.h"

@interface PSTAddressBookManager ()

@property (nonatomic, copy) NSString *filename;

@property (nonatomic, strong) NSMutableDictionary *addressLastUseDate;
@property (nonatomic, strong) NSMutableArray *pendingAddresses;
@property (nonatomic, strong) NSMutableArray *pendingUseAddresses;
@property (nonatomic, strong) NSMutableSet *addressSet;
@property (nonatomic, strong) NSMutableArray *addresses;
@property (nonatomic, strong) NSMutableDictionary *abPeople;

@property (nonatomic, strong) NSOperationQueue *queue;

@end

@implementation PSTAddressBookManager {
	struct {
		unsigned int loading:1;
		unsigned int loaded:1;
		unsigned int modified:1;
		
		unsigned int addressBookLoading:1;
		unsigned int isAddressBookLoaded:1;
		
		unsigned int scheduled:1;
		unsigned int saving:1;
		unsigned int pending:1;
	} _abmFlags;
}

+ (void)load {
	[PSTAddressBookManager sharedManager];
}

#pragma mark - Initialization

+ (instancetype) sharedManager {
	PUISSANT_SINGLETON_DECL(PSTAddressBookManager);
}

#pragma mark - Lifecycle

- (id)init {
	_filename = [@"~/Library/Application Support/DotMail/PSTAddressBook.plist" stringByExpandingTildeInPath];
	_addresses = @[].mutableCopy;
	_addressLastUseDate = @{}.mutableCopy;
	_pendingAddresses = @[].mutableCopy;
	_pendingUseAddresses = @[].mutableCopy;
	_addressSet = [[NSMutableSet alloc]init];
	_queue = [[NSOperationQueue alloc]init];
	[_queue setMaxConcurrentOperationCount:1];
	_abPeople = @{}.mutableCopy;
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_addressBookDatabaseExternallyChanged) name:kABDatabaseChangedExternallyNotification object:nil];
	return self;
}

- (void)dealloc {
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

- (NSDate *)lastUseDateForAddress:(NSString*)email {
	return self.addressLastUseDate[email];
}

- (void)initializeAddressBook {
	[[self _loadAddressBook]subscribeCompleted:^{
		_abmFlags.isAddressBookLoaded = YES;
		_abmFlags.addressBookLoading = NO;
		[[self _loadIfNeeded]subscribeCompleted:^{
			
		}];
	}];
}

- (void)_addressBookDatabaseExternallyChanged {
	[[self _loadAddressBook]subscribeCompleted:^{
		_abmFlags.isAddressBookLoaded = YES;
		_abmFlags.addressBookLoading = NO;
	}];;
}

- (void)addAddress:(MCOAddress *)address {
	if (!_abmFlags.loading) {
		if ([self.addressSet containsObject:address]) return;

		[self.addressSet addObject:address];
		[_addresses addObject:address];
		_abmFlags.modified = YES;
		[self _scheduleSave];
		
	} else {
		[self.pendingAddresses addObject:address];
	}
}

- (void)addAddresses:(NSArray *)addressObjects {
	for (MCOAddress *address in addressObjects) {
		[self addAddress:address];
	}
}

- (void)cacheAddress:(MCOAddress *)address {
	if (address.mailbox != nil) {
		[self _load];
		if (_abmFlags.loading == NO) {
			[self.addressLastUseDate setObject:NSDate.date forKey:address.mailbox];
		} else {
			[self.pendingUseAddresses addObject:address];
		}
	}
}

- (void)cacheAddresses:(NSArray *)addressObjects {
	for (MCOAddress *address in addressObjects) {
		[self cacheAddresses:addressObjects];
	}
}

- (NSArray *)search:(NSString *)string {
	if (_abmFlags.isAddressBookLoaded) {
		if (!_abmFlags.addressBookLoading) {
			NSMutableArray *retVal = @[].mutableCopy;
			if (string.length == 0) {
				return [NSArray array];
			} else {
				NSMutableSet *uniquingSet = [NSMutableSet set];
				for (ABPerson *person in [self.abPeople objectEnumerator]) {
					if ([person dm_allEmailsForPerson].count != 0) {
						for (NSString *email in [person dm_allEmailsForPerson]) {
							if ([email hasPrefix:string]) {
								PSTInsertCompletionForMatchedEmail(email, person, person.dm_displayName, uniquingSet, email, retVal);
							}
						}
						if ([person.dm_displayName hasPrefix:string]) {
							for (NSString *email in [person dm_allEmailsForPerson]) {
								PSTInsertCompletion(email, person, person.dm_displayName, uniquingSet, retVal);
							}
						}
						if ([person.dm_firstMiddleLastName hasPrefix:string]) {
							for (NSString *email in [person dm_allEmailsForPerson]) {
								PSTInsertCompletion(email, person, person.dm_displayName, uniquingSet, retVal);
							}
						}
						if ([person.dm_lastMiddleFirstName hasPrefix:string]) {
							for (NSString *email in [person dm_allEmailsForPerson]) {
								PSTInsertCompletion(email, person, person.dm_displayName, uniquingSet, retVal);
							}
						}
						if ([person.dm_firstLastName hasPrefix:string]) {
							for (NSString *email in [person dm_allEmailsForPerson]) {
								PSTInsertCompletion(email, person, person.dm_displayName, uniquingSet, retVal);
							}
						}
						if ([person.dm_lastFirstName hasPrefix:string]) {
							for (NSString *email in [person dm_allEmailsForPerson]) {
								PSTInsertCompletion(email, person, person.dm_displayName, uniquingSet, retVal);
							}
						}
						if ([person.dm_nickName hasPrefix:string]) {
							for (NSString *email in [person dm_allEmailsForPerson]) {
								PSTInsertCompletion(email, person, person.dm_displayName, uniquingSet, retVal);
							}
						}
					}
				}
			}
			return [retVal sortedArrayUsingFunction:PSTCompareAddressUseDates context:NULL];
		}
	}
	return @[];
}

- (void)_scheduleSave {
	if (_abmFlags.scheduled) return;
	if (_abmFlags.saving) {
		_abmFlags.pending = YES;
		return;
	}
	@weakify(self);
	[[self _runSave] subscribeCompleted:^{
		@strongify(self);
		_abmFlags.saving = NO;
		if (_abmFlags.pending == NO) {
			return;
		} else {
			_abmFlags.pending = NO;
			[self _scheduleSave];
		}
	}];
}

- (RACSignal *)_runSave {
	_abmFlags.scheduled = NO;
	_abmFlags.modified = NO;
	_abmFlags.saving = YES;
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		return [RACScheduler.scheduler schedule:^{
			@strongify(self);
			NSMutableDictionary *dictToSave = @{}.mutableCopy;
			if (self.addresses != nil) {
				[dictToSave setObject:self.addresses forKey:@"Addresses"];
			}
			if (self.addressLastUseDate != nil) {
				[dictToSave setObject:self.addressLastUseDate forKey:@"LastUseDates"];
			}
			[NSKeyedArchiver archiveRootObject:dictToSave toFile:self.filename];
		}];
	}];
}

- (NSArray *)addresses {
	[self _load];
	return _addresses;
}

- (void)_load {
	if (!_abmFlags.isAddressBookLoaded) {
		[[self _loadAddressBook]subscribeCompleted:^{
			_abmFlags.isAddressBookLoaded = YES;
			_abmFlags.addressBookLoading = NO;
			[[self _loadIfNeeded]subscribeCompleted:^{
				_abmFlags.loading = NO;
				_abmFlags.loaded = YES;
				[self addAddresses:self.pendingAddresses];
				for (MCOAddress *address in self.pendingAddresses) {
					[self cacheAddress:address];
				}
				[self.pendingUseAddresses removeAllObjects];
			}];
		}];
	} else {
		[[self _loadIfNeeded]subscribeCompleted:^{
			_abmFlags.loading = NO;
			_abmFlags.loaded = YES;
			[self addAddresses:self.pendingAddresses];
			for (MCOAddress *address in self.pendingAddresses) {
				[self cacheAddress:address];
			}
			[self.pendingUseAddresses removeAllObjects];
		}];
	}
}

- (RACSignal *)_loadIfNeeded {
	if (_abmFlags.loaded || _abmFlags.loading) {
		return nil;
	} else {
		_abmFlags.loading = YES;
		return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
			return [RACScheduler.scheduler schedule:^{
				NSDictionary *addressBookDictionary = [NSKeyedUnarchiver unarchiveObjectWithFile:self.filename];
				[_addresses addObjectsFromArray:addressBookDictionary[@"Addresses"]];
				[self.addressLastUseDate addEntriesFromDictionary:addressBookDictionary[@"LastUseDates"]];
				[self.addressSet addObjectsFromArray:_addresses];
				[subscriber sendCompleted];
			}];
		}] deliverOn:RACScheduler.mainThreadScheduler];
	}
}

- (RACSignal *)_loadAddressBook {
	if (_abmFlags.addressBookLoading) {
		return nil;
	} else {
		_abmFlags.addressBookLoading = YES;
		@weakify(self);
		return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
			@strongify(self);
			return [RACScheduler.scheduler schedule:^{
				@strongify(self);
				NSArray *people = ABAddressBook.sharedAddressBook.people;
				for (ABPerson *person in people) {
					for (NSString *email in [person dm_allEmailsForPerson]) {
						if ([self.abPeople objectForKey:email.lowercaseString] == nil) {
							[self.abPeople setObject:person forKey:email.lowercaseString];
						}
					}
				}
				[subscriber sendCompleted];
			}];
		}] deliverOn:RACScheduler.mainThreadScheduler];
	}
}

#pragma mark - Internal

static NSInteger PSTCompareAddressUseDates(NSString *address1, NSString *address2, void *context) {
	NSDate *lepFirstUseDate = [PSTAddressBookManager.sharedManager lastUseDateForAddress:address1];
	NSDate *lepSecondUseDate = [PSTAddressBookManager.sharedManager lastUseDateForAddress:address2];
	
	return [lepFirstUseDate compare:lepSecondUseDate];
}


static void PSTInsertCompletion(NSString *email, ABPerson *person, NSString *name, NSMutableSet *uniquingSet, NSMutableArray *matchingWrappers) {
	PSTInsertCompletionForMatchedEmail(email, person, name, uniquingSet, nil, matchingWrappers);
}

static void PSTInsertCompletionForMatchedEmail(NSString *email, ABPerson *person, NSString *name, NSMutableSet *uniquingSet, NSString *matchedEmail, NSMutableArray *matchingWrappers) {
	if (![uniquingSet containsObject:email]) {
		NSString *wrapperString = @"";
		if (name != nil) {
			wrapperString = [NSString stringWithFormat:@"%@ <%@>", name, email];
		} else if (matchedEmail != nil) {
			wrapperString = [NSString stringWithFormat:@"%@ (%@)", email, name];
		}
		[matchingWrappers addObject:wrapperString];
		[uniquingSet addObject:email];
	}
}

@end


@implementation PSTAddressBookManager (PSTABPersonSearch)

- (ABPerson *)personForEmail:(NSString *)email {
	ABPerson *person = nil;
	@synchronized(self) {
		person = [self.abPeople objectForKey:email.lowercaseString];
	}
	return person;
}

@end
