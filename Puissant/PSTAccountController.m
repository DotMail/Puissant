//
//  CFIUnifiedAccount.m
//  DotMail
//
//  Created by Robert Widmann on 8/5/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTAccountController.h"
#import "PSTMailAccount.h"
#import "NSString+PSTUUID.h"
#import "PSTConversation.h"

@interface PSTAccountController ()

@property (nonatomic, copy) NSString *identifier;

@end

@implementation PSTAccountController {
	NSMutableArray *_accounts;
}

#pragma mark - Lifecycle

- (id)init {
	self = [super init];

	_identifier = [NSString dmUUIDString];
	_selectedFolder = PSTFolderTypeNone;
	
	return self;
}

- (id)initWithAccount:(PSTMailAccount *)account {
	self = [self init];
	
	self.accounts = @[account].mutableCopy;
	
	return self;
}

- (id)initWithAccounts:(NSArray *)accounts {
	self = [self init];
	
	self.accounts = accounts.mutableCopy;
	
	return self;
}

- (void)dealloc {
	[self _clearAccounts];
}

#pragma mark - Sync

- (void)refreshSync {
	for (PSTMailAccount *account in self.accounts) {
		if (!account.loading) [account refreshSync];
	}
}

#pragma mark - Folder Selection

- (void)setSelectedFolder:(PSTFolderType)selectedFolder {
	for (PSTMailAccount *account in self.accounts) {
		if ([account isSelectionAvailable:selectedFolder]) {
			[account setSelected:selectedFolder];
		}
		else {
			[account setSelected:PSTFolderTypeNone];
		}
	}
	_selectedFolder = selectedFolder;
}

- (void)selectInbox {
	for (PSTMailAccount *account in self.accounts) {
		PSTFolderType selected = 0;
		if (_selectedFolder != PSTFolderTypeInbox) {
			if (_selectedFolder != PSTFolderTypeStarred) {
				selected = PSTFolderTypeInbox;
			}
			else {
				selected =  PSTFolderTypeStarred;
			}
		} else {
			selected = PSTFolderTypeImportant;
		}
		[account setSelected:selected];
	}
}

- (void)searchWithTerms:(NSArray *)terms complete:(BOOL)complete searchStringToComplete:(NSAttributedString *)attributedString {
	for (PSTMailAccount *account in self.accounts) {
		[account searchWithTerms:terms complete:complete searchStringToComplete:attributedString];
	}
}

//TODO
- (NSDictionary *)searchSuggestionsTerms {
//	NSMutableDictionary *result = @{}.mutableCopy;
//	NSMutableSet *uniquer = [[NSMutableSet alloc] init];
//	
//	for (PSTMailAccount *account in self.accounts) {
//		for (id suggestion in [account searchSuggestions]) {
//			if (![result objectForKey:suggestion]) {
//				[result setObject:@[].mutableCopy forKey:suggestion];
//			}
//			for (NSString *obj in [result objectForKey:suggestion]) {
//				//
//			}
//		}
//	}
//	
	return @{};
}

- (void)cancelSearch {
	for (PSTMailAccount *account in self.accounts) {
		[account cancelSearch];
	}
}

- (NSData *)dataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path {
	return [self.mainAccount dataForMessage:message atPath:path];
}

- (BOOL)hasDataForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	return [self.mainAccount hasDataForMessage:(MCOIMAPMessage *)message atPath:path];
}

- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	return [self.mainAccount previewForMessage:message atPath:path];
}

- (void)deleteConversation:(PSTConversation *)conversation {
	[conversation.account deleteConversation:conversation];
}

#pragma mark - Conversation Management

- (void)_updateConversations {
	PSTPropogateValueForKey(self.currentConversations, {
		NSInteger msgCount = 0;
		
		for (PSTMailAccount *account in self.accounts) {
			msgCount += account.currentConversations.count;
		}
		NSMutableArray *newConversations = [NSMutableArray arrayWithCapacity:msgCount];
		
		for (PSTMailAccount *account in self.accounts) {
			[newConversations addObjectsFromArray:account.currentConversations];
		}
		if (_selectedFolder != PSTFolderTypeNextSteps) {
			[newConversations sortUsingSelector:@selector(compare:)];
		}
		else {
			[newConversations sortUsingSelector:@selector(compareWithActionSteps:)];
		}
		_currentConversations = newConversations;
	});
}

- (void)_updateSearchResult {
	PSTPropogateValueForKey(self.currentConversations, {
		NSInteger msgCount = 0;
		
		for (PSTMailAccount *account in self.accounts) {
			msgCount += account.currentSearchResult.count;
		}
		NSMutableArray *newConversations = [NSMutableArray arrayWithCapacity:msgCount];
		
		for (PSTMailAccount *account in self.accounts) {
			[newConversations addObjectsFromArray:account.currentSearchResult];
		}
		if (_selectedFolder != PSTFolderTypeNextSteps) {
			[newConversations sortUsingSelector:@selector(compare:)];
		}
		else {
			[newConversations sortUsingSelector:@selector(compareWithActionSteps:)];
		}
		_currentConversations = newConversations;
	});
}

- (void)setSelectedLabel:(NSString *)selectedLabel {
	if (self.accounts.count == 0 || self.accounts.count > 1) {
		return;
	} else {
		[self.mainAccount setSelectedLabel:selectedLabel];
	}
}

- (RACSignal *)attachmentsSignal {
	if (self.accounts.count == 1) {
		return self.mainAccount.attachmentsSignal;
	}
	NSMutableSet *signals = [[NSMutableSet alloc]init];
	for (PSTMailAccount *account in self.accounts) {
		[signals addObject:account.attachmentsSignal];
	}
	return [RACSignal merge:signals];
}

- (RACSignal *)facebookMessagesSignal {
	return self.mainAccount.facebookMessagesSignal;
}

- (RACSignal *)twitterMessagesSignal {
	return self.mainAccount.twitterMessagesSignal;
}

#pragma mark - Account Controller Methods

- (BOOL)hasMultipleAccounts {
	return (self.accounts.count > 1 ? YES : NO);
}

- (PSTMailAccount *)mainAccount {
	if (_accounts.count == 0) {
		return nil;
	}
	return [self.accounts objectAtIndex:0];
}

- (NSString *)email {
	if (_accounts.count == 0) {
		return nil;
	}
	return [(PSTMailAccount *)[self.accounts objectAtIndex:0] email];
}

- (NSString *)selectedLabel {
	NSString *result = nil;
	if (_accounts.count == 0) {
		return nil;
	}
	if (_accounts.count > 1) {
		return nil;
	} else {
		result = self.mainAccount.selectedLabel;
	}
	return result;
}

- (BOOL)isFolderSelectionAvailable:(PSTFolderType)selection {
	if (_accounts.count == 0) {
		return YES;
	}
	for (PSTMailAccount *account in _accounts) {
		if (![account isSelectionAvailable:selection]) {
			return NO;
		}
	}
	return YES;
}

- (NSArray *)visibleLabels {
	if (_accounts.count == 0) {
		return @[];
	}
	if (_accounts.count >= 2) {
		return @[];
	}
	return self.mainAccount.visibleLabels;
}

- (MCOAddress *)addressValueWithName:(BOOL)name {
	return [self.mainAccount addressValueWithName:name];
}

#pragma mark - Folder Counts

- (NSUInteger)countForFolder:(PSTFolderType)folder {
	NSUInteger result = 0;
	if (_accounts.count != 0) {
		if (_accounts.count == 1) {
			result = [self.mainAccount countForFolder:folder];
		} else {
			for (PSTMailAccount *account in _accounts) {
				result += [account countForFolder:folder];
			}
		}
	}
	return result;
}

- (NSUInteger)unreadCountForFolder:(PSTFolderType)folder {
	NSUInteger retVal = 0;
	if (_accounts.count != 0) {
		if (_accounts.count == 1) {
			retVal = [self.mainAccount unreadCountForFolder:folder];
		} else {
			for (PSTMailAccount *account in _accounts) {
				retVal += [account unreadCountForFolder:folder];
			}
		}
	}
	return retVal;
}

- (BOOL)loading {
	return self.mainAccount.loading;
}

#pragma mark - NSObject

- (NSString *)description {
	NSString *result = nil;
	if (self.hasMultipleAccounts) {
		result = [NSString stringWithFormat:@"<%@:%p - Unified Account Controller: %@>", [self class], self, self.accounts];
	} else {
		result = [NSString stringWithFormat:@"<%@:0x%p - %@>", [self class], self, self.email];
	}
	return result;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (![keyPath isEqualToString:@"currentConversations"]) {
		if (![keyPath isEqualToString:@"currentSearchResult"]) {
			[super willChangeValueForKey:keyPath];
			[super didChangeValueForKey:keyPath];
			return;
		} else {
			[self _updateSearchResult];
		}
	} else {
		[self _updateConversations];
	}
}

#pragma mark - Private

- (void)_countUpdated:(NSNotification *)notification {
	[NSNotificationCenter.defaultCenter postNotificationName:PSTMailUnifiedAccountCountUpdated object:self userInfo:[notification userInfo]];
}

- (void)_colorsChanged:(NSNotification *)notification {
	[NSNotificationCenter.defaultCenter postNotificationName:PSTAccountControllerLabelsColorsChanged object:self userInfo:[notification userInfo]];
}

- (void)setAccounts:(NSMutableArray *)accounts {
	[self _clearAccounts];
	_accounts = accounts;
	NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
	
	for (PSTMailAccount *account in self.accounts) {
		[center addObserver:self selector:@selector(_messageFetched:) name:PSTMailAccountFetchedMessageNotification object:account];
		[center addObserver:self selector:@selector(_countUpdated:) name:PSTMailAccountCountUpdated object:account];
		[center addObserver:self selector:@selector(_colorsChanged:) name:PSTMailAccountLabelsColorsChanged object:account];
		
		[account addObserver:self forKeyPath:@"savingAttachment" options:0 context:nil];
		[account addObserver:self forKeyPath:@"currentConversations" options:0 context:nil];
		[account addObserver:self forKeyPath:@"syncing" options:0 context:nil];
		[account addObserver:self forKeyPath:@"commiting" options:0 context:nil];
		[account addObserver:self forKeyPath:@"sending" options:0 context:nil];
		[account addObserver:self forKeyPath:@"searchSuggestions" options:0 context:nil];
		[account addObserver:self forKeyPath:@"labels" options:0 context:nil];
		[account addObserver:self forKeyPath:@"loading" options:0 context:nil];
		[account setSelected:PSTFolderTypeInbox];
	}
	
	[self _updateConversations];
	RAC(self,loading) = RACObserve(self.mainAccount,loading);
}

- (void)_clearAccounts {
	NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
	for (PSTMailAccount *account in self.accounts) {
		[center removeObserver:self name:PSTMailAccountFetchedMessageNotification object:account];
		[center removeObserver:self name:PSTMailAccountCountUpdated object:account];
		[center removeObserver:self name:PSTMailAccountLabelsColorsChanged object:account];
		
		[account removeObserver:self forKeyPath:@"savingAttachment"];
		[account removeObserver:self forKeyPath:@"currentConversations"];
		[account removeObserver:self forKeyPath:@"syncing"];
		[account removeObserver:self forKeyPath:@"commiting"];
		[account removeObserver:self forKeyPath:@"sending"];
		[account removeObserver:self forKeyPath:@"searchSuggestions"];
		[account removeObserver:self forKeyPath:@"labels"];
		[account removeObserver:self forKeyPath:@"loading"];
	}
	[_accounts removeAllObjects];
	_accounts = nil;
	[self _updateConversations];
}

- (BOOL)isEqual:(id)object {
	if (object == nil) return NO;
	
	NSString *otherEmail = nil;
	if ([object respondsToSelector:@selector(email)])
		otherEmail = [object email];
	else
		otherEmail = object;
	
	if (self == object) {
		return YES;
	}
	if (![otherEmail isKindOfClass:[NSString class]]) {
		return NO;
	}
	
	return [self.email isEqualToString:otherEmail];
}

@end