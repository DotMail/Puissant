//
//  PSTIMAPMailAccount.m
//  Puissant
//
//  Created by Robert Widmann on 5/14/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTIMAPMailAccount.h"
#import "PSTSerializableMessage.h"
#import "NPReachability.h"
#import "MCOIMAPMessage+PSTExtensions.h"
#import "PSTIMAPAccountSynchronizer.h"
#import "FXKeychain.h"
#import "PSTAccountManager.h"
#import "PSTAccountChecker.h"
#import "PSTActivity.h"
#import "PSTActivityManager.h"
#import "PSTConversation.h"
#import "MCOIMAPSession+PSTExtensions.h"
#import "PSTCachedMessage.h"
#import "NSColor+PSTHexadecimalAdditions.h"

static MCOIMAPFolder *PSTFolderFromEnumInSynchronizer(PSTFolderType selection, PSTIMAPAccountSynchronizer *_imapSynchronizer, NSString *label);
static NSSet *PSTMainFolderSetForProvider(MCOMailProvider *mailProvider);
static NSArray *PSTIgnoredMailboxesArray = nil;
static NSArray *PSTDefaultLabelColorsList = nil;

@interface PSTIMAPMailAccount ()

@property (nonatomic, strong) PSTIMAPAccountSynchronizer *imapSynchronizer;

@property (nonatomic, assign) NSUInteger inboxRefreshDelay;
@property (nonatomic, strong) NSString *providerIdentifier;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, assign) unichar namespaceDelimiter;
@property (nonatomic, strong) MCOSMTPSession *smtpAccount;

@property (nonatomic, strong) NSDictionary *xListMapping;
@property (nonatomic, strong) NSDictionary *folderForLabels;
@property (nonatomic, strong) NSMutableDictionary *saveBeforeSendDictionary;
@property (nonatomic, strong) NSMutableSet *hiddenLabels;

@property (nonatomic, copy) NSString *MXProvider;
@property (nonatomic, copy) NSString *namespacePrefix;

@property (nonatomic, strong) NSArray *visibleLabels;
@property (nonatomic, strong) NSSet *visibleLabelsSet;

@property (nonatomic, strong) NSArray *previousLabels;
@property (nonatomic, strong) NSMutableArray *labels;
@property (nonatomic, strong) PSTAccountChecker *imapChecker;
@property (nonatomic, strong) PSTAccountChecker *checker;

@property (nonatomic, strong) MCONetService *smtpService;
@property (nonatomic, strong) MCONetService *imapService;
@property (nonatomic, copy) NSDictionary *customSmtpInfo;
@property (nonatomic, copy) NSDictionary *customImapInfo;

@property (nonatomic, strong) NSMutableArray *messageToSendQueue;
@property (nonatomic, strong) NSMutableArray *previousMessageIDs;
@property (nonatomic, strong) NSMutableSet *ignoredNotificationForMessageID;

@property (nonatomic, strong) NSMutableDictionary *folderColorsMap;
@property (nonatomic, strong) NSMutableDictionary *folderColorsCache;

@property (nonatomic, strong) NSMutableArray *foldersArray;
@property (nonatomic, strong) NSMutableArray *nonSelectableFolders;
@property (nonatomic, strong) NSMutableArray *savedFolderPaths;

@property (nonatomic, strong) NSMutableArray *smtpActivities;

@property (nonatomic, assign) NSUInteger sendMessagesNumberCurrentProgress;
@property (nonatomic, assign) NSUInteger sendMessagesNumberMaximumProgress;
@property (nonatomic, assign) NSUInteger sendingLastGlobalProgress;

@property (nonatomic, assign) NSUInteger modifiedConversationsLock;

@property (nonatomic, assign) NSTimeInterval lastLabelsRefreshTimestamp;

@end

@implementation PSTIMAPMailAccount {
	NSString *_name;
	NSString *_email;
	struct {
		unsigned int refreshingLabels:1;
		unsigned int forceRefresh:1;
		unsigned int foldersUpdating:1;
		unsigned int authenticationError:1;
		unsigned int retrySend:1;
		unsigned int processingSendQueue:1;
		unsigned int waitingUntilAllOperationsHaveFinished:1;
		unsigned int disableCountUpdated:1;
	} _accountFlags;
}

+ (void)initialize {
	if (self == PSTIMAPMailAccount.class) {
		if (PSTIgnoredMailboxesArray == nil) {
			PSTIgnoredMailboxesArray = @[
				@"\\[Gmail\\].*",
				@"\\[Google Mail\\].*",
				@"Deleted Messages",
				@"Drafts",
				@"Sent",
				@"Sent Messages",
				@"Trash"
			];
		}
	}
}

#pragma mark - HTML Signature Helpers

+ (NSString *)defaultHTMLSignatureSuffix {
	return @"Sent with <a href=\"http://www.dotmailapp.com/?%@\">DotMail</a>";
}

+ (NSArray *)labelColorsList {
	if (PSTDefaultLabelColorsList == nil) {
		NSString *labelsColorPath = [[NSBundle mainBundle] pathForResource:@"label-colors" ofType:@"plist"];
		NSArray *hexValues = [NSArray arrayWithContentsOfFile:labelsColorPath];
		PSTDefaultLabelColorsList = [NSMutableArray array];
		for (NSString *hexValue in hexValues) {
			[(NSMutableArray *)PSTDefaultLabelColorsList addObject:[NSColor colorFromHexadecimalValue:hexValue]];
		}
	}
	return PSTDefaultLabelColorsList;
}

#pragma mark - Lifecycle

- (id)init {
	_folderColorsMap = [[NSMutableDictionary alloc] init];
	_folderColorsCache = [[NSMutableDictionary alloc] init];
	
	_smtpActivities = [[NSMutableArray alloc] init];
	_messageToSendQueue = [[NSMutableArray alloc] init];
	_previousMessageIDs = [[NSMutableArray alloc] init];
	_hiddenLabels = [[NSMutableSet alloc] init];
	_saveBeforeSendDictionary = [[NSMutableDictionary alloc] init];
	_ignoredNotificationForMessageID = [[NSMutableSet alloc] init];
	_inboxRefreshDelay = 0;
	
	self.notificationsEnabled = YES;
	
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
	self = [self init];
	
	if ([dictionary objectForKey:@"PSTName"]) {
		[self setName:[dictionary objectForKey:@"PSTName"]];
	}
	if ([dictionary objectForKey:@"PSTHTMLSignature"]) {
		[self setHtmlSignature:[dictionary objectForKey:@"PSTHTMLSignature"]];
	}
	if ([dictionary objectForKey:@"PSTEmail"]) {
		[self setEmail:[dictionary objectForKey:@"PSTEmail"]];
	}
	if ([dictionary objectForKey:@"PSTPassword"]) {
		[self setPassword:[dictionary objectForKey:@"PSTPassword"]];
	}
	if ([dictionary objectForKey:@"PSTRefreshDelay"]) {
		[self setInboxRefreshDelay:[[dictionary objectForKey:@"PSTRefreshDelay"] integerValue]];
	}
	if ([dictionary objectForKey:@"PSTMXProvider"]) {
		[self setMXProvider:[dictionary objectForKey:@"PSTMXProvider"]];
	}
	if ([dictionary objectForKey:@"PSTProvider"]) {
		[self setProviderIdentifier:[dictionary objectForKey:@"PSTProvider"]];
	}
	if ([dictionary objectForKey:@"PSTXListMapping"]) {
		[self setXListMapping:[dictionary objectForKey:@"PSTXListMapping"]];
	}
	if ([dictionary objectForKey:@"PSTServiceType"]) {
		if (![[dictionary objectForKey:@"PSTServiceType"] isEqualToString:@"imap"]) {
			[NSException raise:@"PSTInvalidAccountSynchronizerType" format:@"Attempted to initialize a %@ with a POP Service type", NSStringFromClass(self.class)];
		}
	}
	self.savedFolderPaths = [dictionary objectForKey:@"PSTFolders"];
	if ([dictionary objectForKey:@"PSTFolderColors"]) {
//		[self setFolderColorsMap:[[NSKeyedUnarchiver unarchiveObjectWithData:[dictionary objectForKey:@"PSTFolderColors"]]mutableCopy]];
	}
	if ([dictionary objectForKey:@"PSTSMTPService"]) {
		[self setSmtpService:[MCONetService serviceWithInfo:[dictionary objectForKey:@"PSTSMTPService"]]];
	}
	if ([dictionary objectForKey:@"PSTIMAPService"]) {
		[self setImapService:[MCONetService serviceWithInfo:[dictionary objectForKey:@"PSTIMAPService"]]];
	}
	if ([dictionary objectForKey:@"PSTNamespacePrefix"] && [[dictionary objectForKey:@"PSTNamespacePrefix"] length] != 0) {
		[self setNamespaceDelimiter:[(NSString *)[dictionary objectForKey:@"PSTNamespacePrefix"] characterAtIndex:0]];
	}
	self.selected = PSTFolderTypeInbox;

	return self;
}

- (void)dealloc {
	if (_imapSynchronizer) {
		[_imapSynchronizer removeObserver:self forKeyPath:@"error"];
		[_imapSynchronizer removeObserver:self forKeyPath:@"committing"];
		[_imapSynchronizer removeObserver:self forKeyPath:@"savingAttachment"];
		[_imapSynchronizer removeObserver:self forKeyPath:@"syncing"];
		[_imapSynchronizer removeObserver:self forKeyPath:@"currentConversations"];
		[_imapSynchronizer removeObserver:self forKeyPath:@"searchSuggestions"];
		[_imapSynchronizer setDelegate:nil];
		[_imapSynchronizer invalidateSynchronizer];
	}
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Colors

- (void)setColor:(NSColor *)color forLabel:(NSString *)label {
	[self.folderColorsCache setObject:color forKey:label];
	[self.folderColorsMap setObject:[color hexadecimalValue] forKey:label];
	[NSNotificationCenter.defaultCenter postNotificationName:PSTMailAccountLabelColorsUpdatedNotification object:self];
}

- (NSColor *)colorForLabel:(NSString *)label {
	NSColor *result = [self.folderColorsCache objectForKey:label];
	if (!result && [self.folderColorsMap objectForKey:label]) {
		result = [NSColor colorFromHexadecimalValue:[self.folderColorsMap objectForKey:label]];
		if (result) {
			[self.folderColorsCache setObject:result forKey:label];
		}
	}
	return result;
}

#pragma mark - Synchronizers

- (BOOL)hasDataForMessage:(MCOIMAPMessage*)message atPath:(NSString *)path {
	return [_imapSynchronizer hasDataForMessage:message atPath:path];
}

- (NSData *)dataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path {
	return [_imapSynchronizer dataForMessage:message atPath:path];
}

- (BOOL)hasDataForAttachment:(MCOAbstractPart*)message atPath:(NSString *)path {
	return [_imapSynchronizer hasDataForAttachment:message atPath:path];
}

- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment atPath:(NSString *)path {
	return [_imapSynchronizer dataForAttachment:attachment atPath:path];
}

- (NSData *)dataForAttachment:(MCOAbstractPart *)attachment onMessage:(MCOIMAPMessage *)message atPath:(NSString *)path {
	return [_imapSynchronizer dataForAttachment:attachment onMessage:message atPath:path];
}

#pragma mark - Social Signals

- (RACSignal *)facebookMessagesSignal {
	return [_imapSynchronizer facebookMessagesSignal];
}

- (RACSignal *)twitterMessagesSignal {
	return [_imapSynchronizer twitterMessagesSignal];
}

- (RACSignal *)attachmentsSignal {
	return [_imapSynchronizer attachmentsSignal];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (_accountFlags.waitingUntilAllOperationsHaveFinished) {
		return;
	}
	[super willChangeValueForKey:keyPath];
	[super didChangeValueForKey:keyPath];
}

#pragma mark - Synchronization

- (BOOL)canRefreshStarred {
	return ([_imapSynchronizer starredFolder] != nil);
}

- (void)setSelected:(PSTFolderType)selected {
	[super setSelected:selected];
	[_imapSynchronizer setSelectedStarred:NO];
	[_imapSynchronizer setSelectedUnread:NO];
	[_imapSynchronizer setSelectedNextSteps:NO];
	
	switch (self.selected) {
		case PSTFolderTypeStarred:
			if ([_imapSynchronizer starredFolder] == nil) {
				[_imapSynchronizer setSelectedStarred:YES];
				[_imapSynchronizer setSelectedFolder:nil];
			}
			break;
		case PSTFolderTypeLabel:
			[self _applySelectedLabel];
			break;
		case PSTFolderTypeNone:
			[_imapSynchronizer setSelectedFolder:nil];
			[_imapSynchronizer setSelectedFolder:PSTFolderFromEnumInSynchronizer(selected, _imapSynchronizer, self.selectedLabel)];
			break;
		case PSTFolderTypeNextSteps:
			[_imapSynchronizer setSelectedNextSteps:YES];
			[_imapSynchronizer setSelectedFolder:PSTFolderFromEnumInSynchronizer(selected, _imapSynchronizer, self.selectedLabel)];
			break;
		case PSTFolderTypeImportant:
		case PSTFolderTypeUnread:
			[_imapSynchronizer setSelectedUnread:YES];
			[_imapSynchronizer setSelectedFolder:PSTFolderFromEnumInSynchronizer(selected, _imapSynchronizer, self.selectedLabel)];
			break;
		case PSTFolderTypeInbox:
			[_imapSynchronizer setSelectedFolder:PSTFolderFromEnumInSynchronizer(selected, _imapSynchronizer, self.selectedLabel)];
			break;
		default:
			[_imapSynchronizer setSelectedFolder:PSTFolderFromEnumInSynchronizer(selected, _imapSynchronizer, self.selectedLabel)];
			break;
	}
	[PSTAccountManager.defaultManager synchronize];
}


- (void)checkNotifications {
	[_imapSynchronizer checkNotifications];
}


- (BOOL)isSelectionAvailable:(PSTFolderType)selection {
	BOOL result = YES;
	if (selection != PSTFolderTypeStarred && selection != PSTFolderTypeNextSteps && selection != PSTFolderTypeImportant && selection != PSTFolderTypeInbox && _imapSynchronizer) {
		result = NO;
		MCOIMAPFolder *folder = PSTFolderFromEnumInSynchronizer(selection, _imapSynchronizer, self.selectedLabel);
		if (folder) {
			result = [_imapSynchronizer isSelectedFolderAvailable:folder];
		}
	} else {
		if ([_imapSynchronizer starredFolder] == nil) {
			return YES;
		}
	}
	return result;
}

- (void)save {
	[[_imapSynchronizer saveState] subscribeCompleted:^{
	}];
}

- (void)waitUntilAllOperationsHaveFinished {
	_accountFlags.waitingUntilAllOperationsHaveFinished = YES;
	[_imapSynchronizer waitUntilAllOperationsHaveFinished];
	_accountFlags.waitingUntilAllOperationsHaveFinished = NO;
}

- (NSArray *)allLabels {
	return _labels;
}

- (NSString *)name {
	return _name;
}

- (void)setName:(NSString *)name {
	_name = name;
}

- (NSString *)email {
	return _email;
}

- (void)setEmail:(NSString *)email {
	_email = email;
}

- (NSString *)password {
	NSString *passwordPossiblity = [FXKeychain.defaultKeychain objectForKey:self.email];
	if (passwordPossiblity != nil) {
		[self setPassword:passwordPossiblity];
	}
	return _password;
}

- (MCOAddress *)addressValueWithName:(BOOL)name {
	return [MCOAddress addressWithDisplayName:(name ? self.name : nil) mailbox:self.email];
}

//Encode all the things!
- (NSDictionary *)info {
	NSMutableDictionary *retVal = [NSMutableDictionary dictionary];
	if (self.name != nil) {
		[retVal setObject:self.name forKey:@"PSTName"];
	}
	if (self.htmlSignature != nil) {
		[retVal setObject:self.htmlSignature forKey:@"PSTHTMLSignature"];
	}
	[retVal setObject:self.email forKey:@"PSTEmail"];
	[retVal setObject:[NSNumber numberWithUnsignedInteger:self.inboxRefreshDelay] forKey:@"RefreshDelay"];
	if (self.MXProvider != nil) {
		[retVal setObject:self.MXProvider forKey:@"PSTMXProvider"];
	}
	if ([self _folderPaths] != nil) {
		[retVal setObject:[self _folderPaths] forKey:@"PSTFolders"];
	}
	if (self.providerIdentifier != nil) {
		[retVal setObject:self.providerIdentifier forKey:@"PSTProvider"];
	}
	[retVal setObject:@"imap" forKey:@"PSTServiceType"];
	if (self.folderColorsMap) {
		[retVal setObject:[NSKeyedArchiver archivedDataWithRootObject:self.folderColorsMap] forKey:@"PSTFolderColors"];
	}
	if (self.smtpService != nil) {
		[retVal setObject:self.smtpService.info forKey:@"PSTSMTPService"];
	}
	if (self.imapService != nil) {
		[retVal setObject:self.imapService.info forKey:@"PSTIMAPService"];
	}
	if (self.customImapInfo != nil) {
		[retVal setObject:self.customImapInfo forKey:@"PSTIMAPInfo"];
	}
	if (self.customSmtpInfo != nil) {
		[retVal setObject:self.customSmtpInfo forKey:@"PSTSMTPInfo"];
	}
	if (self.xListMapping != nil) {
		[retVal setObject:self.xListMapping forKey:@"PSTXListMapping"];
	}
	if (self.hiddenLabels != nil) {
		[retVal setObject:[self.hiddenLabels allObjects] forKey:@"PSTHiddenLabels"];
	}
	return retVal;
}

- (NSArray *)_folderPaths {
	if (_imapSynchronizer == nil) {
		if (self.savedFolderPaths == nil) {
			return [NSArray array];
		}
	}
	else {
		NSMutableArray *folderPaths = [NSMutableArray array];
		for (MCOIMAPFolder *folder in [_imapSynchronizer folders]) {
			[folderPaths addObject:folder.path];
		}
		return folderPaths;
	}
	return [NSArray array];
}

- (void)setNotificationsEnabled:(BOOL)notificationsEnabled {
	[super setNotificationsEnabled:notificationsEnabled];
	if (_accountFlags.disableCountUpdated) {
		return;
	}
	[NSNotificationCenter.defaultCenter postNotificationName:PSTMailAccountNotificationChanged object:nil];
	[self accountSynchronizerDidUpdateCount:nil];
}

- (void)refreshSync {
	PSTLog(@"refresh sync %@", self);
	[self _setupSync];
	if ([self canRefreshStarred] || self.selected != PSTFolderTypeStarred) {
		[[self.imapSynchronizer refreshSync]subscribeCompleted:^{
				
		}];
	}
}

- (RACSignal *)sendMessage:(id)message {
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		[self _progressSendMessageAdd];
		[self.messageToSendQueue addObject:message];
		if (_accountFlags.processingSendQueue) {
			[subscriber sendCompleted];
		} else {
			[self _sendQueuedMessages];
			[subscriber sendCompleted];
		}
		return nil;
	}];
}

- (RACSignal *)saveMessage:(id)message {
	return [self.imapSynchronizer saveMessage:message];
}

- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	return [self.imapSynchronizer previewForMessage:message atPath:path];
}

#pragma mark - Refresh Sync

- (void)refreshSyncForSelection:(PSTFolderType)selection {
	[self _setupSync];
	[_imapSynchronizer refreshSyncForFolder:PSTFolderFromEnumInSynchronizer(selection, _imapSynchronizer, self.selectedLabel)];
}

- (void)sync {
	[PSTAccountManager.defaultManager synchronize];
	[self _setupSync];
	[[_imapSynchronizer sync]subscribeCompleted:^{
		[[_imapSynchronizer refreshSync]subscribeCompleted:^{
			
		}];
	}];
}

#pragma mark - Folder Getters

- (MCOIMAPFolder *)_folderForLabel:(NSString *)label {
	if ([label isEqualToString:@"INBOX"]) {
		return _imapSynchronizer.inboxFolder;
	}
	return [_imapSynchronizer folderForPath:label];
}

- (NSArray *)currentConversations {
	return [_imapSynchronizer currentConversations];
}

- (NSArray *)currentSearchResult {
	return [_imapSynchronizer currentSearchResult];
}

- (void)_setupSync {
	if (_smtpService != nil) {
		[self _updatePendingPassword];
		return;
	}
}

- (void)_applySelectedLabel {
	if (self.selected != PSTFolderTypeLabel) {
		return;
	}
	else {
		if (self.selectedLabel != nil) {
			if ([self _folderForLabel:self.selectedLabel] == nil) {
				[self _validateSelectedLabel];
			}
			else {
				[_imapSynchronizer setSelectedFolder:[self _folderForLabel:self.selectedLabel]];
			}
		}
		else {
			[_imapSynchronizer setSelectedFolder:_imapSynchronizer.allMailFolder];
		}
	}
}

- (void)_validateSelectedLabel {
	if (self.selectedLabel == nil) {
		return;
	}
	if (self.isSpamLabelSelected) {
		return;
	}
	for (NSString *label in self.labels) {
		if ([label isEqualToString:self.selectedLabel]) {
			return;
		}
	}
	[self setSelectedLabel:nil];
}

- (BOOL)isSpamLabelSelected {
	return [_imapSynchronizer.spamFolder.path isEqualToString:self.selectedLabel];
}

- (void)_refreshSyncAllMail {
	[_imapSynchronizer refreshSyncForFolder:_imapSynchronizer.sentMailFolder];
	if ([self isSelectionAvailable:PSTFolderTypeDrafts]) {
		[_imapSynchronizer refreshSyncForFolder:[_imapSynchronizer allMailFolder]];
	}
}

- (void)_updatePendingPassword {
	if (self.imapSynchronizer.password != nil) {
		return;
	}
	NSString *passwordPossibility = self.password;
	if (passwordPossibility == nil) {
		return;
	}
	else {
		[self.imapSynchronizer setPassword:passwordPossibility];
	}
}

- (void)_updatePendingPasswordForSMTP {
	if (_imapSynchronizer  != nil) {
		if (_imapSynchronizer.password != nil) {
			return;
		}
		NSString *passwordPossibility = self.password;
		if (passwordPossibility == nil) {
			return;
		}
		else {
			[_imapSynchronizer setPassword:passwordPossibility];
		}
	}
}

- (MCOSMTPSession *)smtpAccount {
	if (_smtpAccount == nil) {
		_smtpAccount = [[MCOSMTPSession alloc] init];
		[_smtpAccount setCheckCertificateEnabled:NO];
		[_smtpAccount setUsername:self.email];
		[_smtpAccount setHostname:self.smtpService.hostname];
		[_smtpAccount setPort:self.smtpService.port];
		[_smtpAccount setConnectionType:self.smtpService.connectionType];
		[_smtpAccount setPassword:self.password];
	}
	return _smtpAccount;
}

- (PSTIMAPAccountSynchronizer *)imapSynchronizer {
	if (_imapSynchronizer == nil) {
		PSTIMAPAccountSynchronizer *imapSynchronizer = [[PSTIMAPAccountSynchronizer alloc] init];
		[imapSynchronizer setEmail:self.email];
		[imapSynchronizer setLogin:self.email];
		[imapSynchronizer setPassword:[FXKeychain.defaultKeychain objectForKey:self.email]];
		[imapSynchronizer setHost:self.imapService.hostname];
		[imapSynchronizer setPort:self.imapService.port];
		[imapSynchronizer setConnectionType:self.imapService.connectionType];
		[imapSynchronizer setProviderIdentifier:self.providerIdentifier];
		[imapSynchronizer setNamespacePrefix:self.namespacePrefix];
		[imapSynchronizer setXListMapping:self.xListMapping];
		[imapSynchronizer setInboxRefreshDelay:self.inboxRefreshDelay];
		
		[imapSynchronizer addObserver:self forKeyPath:@"error" options:0 context:nil];
		[imapSynchronizer addObserver:self forKeyPath:@"committing" options:0 context:nil];
		[imapSynchronizer addObserver:self forKeyPath:@"savingAttachment" options:0 context:nil];
		[imapSynchronizer addObserver:self forKeyPath:@"syncing" options:0 context:nil];
		[imapSynchronizer addObserver:self forKeyPath:@"searchSuggestions" options:0 context:nil];
		[imapSynchronizer addObserver:self forKeyPath:@"currentConversations" options:0 context:nil];
		[imapSynchronizer setDelegate:self];

		_imapSynchronizer = imapSynchronizer;
		RAC(self,loading) = RACObserve(self.imapSynchronizer,loading);
	}
	
	return _imapSynchronizer;
}

- (void)setSelectedLabel:(NSString *)selectedLabel {
	[super setSelectedLabel:selectedLabel];
	if (self.selected == PSTFolderTypeLabel) {
		if (self.selectedLabel != nil) {
			MCOIMAPFolder *folder = [self _folderForLabel:selectedLabel];
			if (folder == nil) {
			}
			else {
				[_imapSynchronizer setSelectedFolder:folder];
			}
		}
		else {
			[_imapSynchronizer setSelectedFolder:_imapSynchronizer.allMailFolder];
		}
	}
}

- (void)cancel {
	[_imapSynchronizer cancel];
}

- (void)remove {
	[self cancel];
	[NSFileManager.defaultManager removeItemAtPath:[[NSString stringWithFormat:@"~/Library/Application Support/DotMail/%@.dotmaildb", self.email] stringByExpandingTildeInPath] error:nil];
	[PSTActivityManager.sharedManager clearAllActivitiesFromAccount:self.email];
}

- (void)deleteConversation:(PSTConversation *)conversation {
	[self beginConversationUpdates];
	NSMutableArray *allToDelete = @[].mutableCopy;
	[conversation load];
//	[self _removeDraftsMessagesInConversation:conversation];
	[allToDelete addObjectsFromArray:[self _messagesToFlagAsDeletedInConversation:conversation]];
	for (PSTSerializableMessage *message in allToDelete) {
		message.flags |= MCOMessageFlagDeleted;
		[self addModifiedMessage:message atPath:message.dm_folder.path];
	}
	[self.imapSynchronizer addMessagesToDelete:allToDelete];
	[self endConversationUpdates];
	[_imapSynchronizer removeConversation:conversation];
}

- (NSArray *)_messagesToFlagAsDeletedInConversation:(PSTConversation *)conversation {
	NSMutableArray *result = @[].mutableCopy;
	for (PSTSerializableMessage *message in conversation.messages) {
		if ([message.dm_folder.path isEqualToString:self.imapSynchronizer.trashFolder.path]) {
			[result addObject:message];
		}
	}
	return result;
}

- (void)_updateLabels {
	NSMutableDictionary *folderForLabels = [[NSMutableDictionary alloc] init];
	MCOMailProvider *mailProvider = [[MCOMailProvidersManager sharedManager] providerForIdentifier:self.providerIdentifier];
	NSSet *providerFolderSet = PSTMainFolderSetForProvider(mailProvider);
	NSMutableArray *sortedFolderArray = [NSMutableArray array];
	
	for (MCOIMAPFolder *folder in _imapSynchronizer.folders) {
		if (![providerFolderSet containsObject:folder.path]) {
			if (![folder.path isEqualToString:@"INBOX"]) {
				[sortedFolderArray addObject:folder.path];
				[folderForLabels setObject:folder forKey:folder.path];
			}
		}
	}
	[sortedFolderArray sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	NSMutableArray *foldersArray = [[NSMutableArray alloc] init];
	NSMutableArray *nonSelectableFoldersArray = [[NSMutableArray alloc] init];
	for (MCOIMAPFolder *folder in _imapSynchronizer.folders) {
		if (![folder.path isEqualToString:@"INBOX"]) {
			[foldersArray addObject:folder.path];
			[folderForLabels setObject:folder forKey:folder.path];
		}
	}
	for (MCOIMAPFolder *folder in _imapSynchronizer.nonSelectableFolders) {
		[nonSelectableFoldersArray addObject:folder.path];
		[folderForLabels setObject:folder forKey:folder.path];
	}
	NSMutableArray *visibleLabelsArray = [[NSMutableArray alloc] init];
	for (MCOIMAPFolder *folder in sortedFolderArray) {
		if (![self.hiddenLabels containsObject:folder]) {
			[visibleLabelsArray addObject:folder];
		}
	}
	if (_accountFlags.foldersUpdating == NO) {
		[self willChangeValueForKey:@"labels"];
	}
	self.foldersArray = foldersArray;
	self.nonSelectableFolders = nonSelectableFoldersArray;
	self.visibleLabels = visibleLabelsArray;
	self.visibleLabelsSet = [[NSSet alloc] initWithArray:visibleLabelsArray];
	self.folderForLabels = folderForLabels;
	_labels = sortedFolderArray;	
	if (_accountFlags.foldersUpdating == NO) {
		[self didChangeValueForKey:@"labels"];
	}
	[PSTAccountManager.defaultManager synchronize];
}

- (void)_validateHiddenLabels {
	NSArray *arrayToSet = self.foldersArray;
	NSSet *set = [[NSSet alloc] initWithArray:arrayToSet];
	for (MCOIMAPFolder *folder in [self.hiddenLabels allObjects]) {
		if ([set containsObject:folder]) {
			[self.hiddenLabels removeObject:folder];
		}
	}
}

- (void)_recreateLabelColors {
	for (NSString *label in [self.allLabels arrayByAddingObjectsFromArray:@[ @"All Mail", @"Spam" ]]) {
		if (![self colorForLabel:label]) {
			NSColor *selectedColor = [self.class labelColorsList][arc4random_uniform([self.class labelColorsList].count)];
			[self setColor:selectedColor forLabel:label];
		}
	}
	[NSNotificationCenter.defaultCenter postNotificationName:PSTMailAccountLabelColorsUpdatedNotification object:self];
}

- (void)_sendQueuedMessages {
	if (_accountFlags.processingSendQueue == YES) {
		return;
	}
	if (self.messageToSendQueue.count != 0) {
		[self _setupSync];
		MCOMessageBuilder *messageToSend = [self.messageToSendQueue objectAtIndex:0];
		if (self.smtpAccount.password) {
			_accountFlags.processingSendQueue = YES;
			PSTActivity *sendActivity = [[PSTActivity alloc] init];
			[sendActivity setEmail:self.email];
			[sendActivity setActivityDescription:[NSString stringWithFormat:@"sending email: %@", messageToSend.header.subject]];
			[[PSTActivityManager sharedManager] registerActivity:sendActivity];
			[self willChangeValueForKey:@"sending"];
			[self.smtpActivities addObject:sendActivity];
			[self didChangeValueForKey:@"sending"];
			@weakify(self);
			MCOSMTPSendOperation *op = [self.smtpAccount sendOperationWithData:messageToSend.data];
			[op setProgress:^(unsigned int current, unsigned int maximum) {
				[sendActivity setMaximumProgress:maximum];
				[sendActivity setProgressValue:current];
			}];
			[op start:^(NSError *error) {
				@strongify(self);
				[PSTActivityManager.sharedManager removeActivity:sendActivity];
				_accountFlags.processingSendQueue = NO;
				[self.messageToSendQueue removeObjectAtIndex:0];
				[self _sendQueuedMessages];
			}];
		}
	}
	else {
		[self _afterProcessQueue];
		[self _progressSendMessageDone];
		[NSNotificationCenter.defaultCenter postNotificationName:PSTMailAccountMessageDidSendMessageNotification object:self userInfo:nil];
	}
}

- (void)_afterProcessQueue {
	[self _refreshSyncAllMail];
}

- (void)_progressSendMessageAdd {
	self.sendMessagesNumberMaximumProgress += 1;
}

- (void)_progressSendMessageDone {
	self.sendMessagesNumberCurrentProgress = 0;
	self.sendMessagesNumberMaximumProgress = 0;
	self.sendingLastGlobalProgress = 0;
}

- (NSUInteger)countForFolder:(PSTFolderType)folder {
	NSUInteger result;
	if (folder == PSTFolderTypeStarred) {
		result = [_imapSynchronizer  countForStarred];
	}
	else if (folder == PSTFolderTypeNextSteps) {
		result = [_imapSynchronizer  countForNextSteps];
	} else {
		result = [_imapSynchronizer  countForFolder:PSTFolderFromEnumInSynchronizer(folder, _imapSynchronizer, self.selectedLabel)];
	}
	return result;
}

- (NSUInteger)unreadCountForFolder:(PSTFolderType)folder {
	return [_imapSynchronizer unseenCountForFolder:PSTFolderFromEnumInSynchronizer(folder, _imapSynchronizer, self.selectedLabel)];
}

- (void)beginConversationUpdates {
	self.modifiedConversationsLock += 1;
	[_imapSynchronizer  beginConversationUpdates];
}

- (void)endConversationUpdates {
	self.modifiedConversationsLock -= 1;
	[_imapSynchronizer  endConversationUpdates];
}

- (void)addModifiedMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	[_imapSynchronizer addModifiedMessage:message atPath:path];
	if (self.modifiedConversationsLock != 0) {
		return;
	}
	[_imapSynchronizer sync];
}

- (void)searchWithTerms:(NSArray *)terms complete:(BOOL)complete searchStringToComplete:(NSAttributedString *)attributedString {
	[_imapSynchronizer searchWithTerms:terms complete:complete searchStringToComplete:attributedString];
}

- (NSArray *)searchSuggestions {
	return [_imapSynchronizer searchSuggestions];
}

- (void)cancelSearch {
	[_imapSynchronizer cancelSearch];
	[_imapSynchronizer cancelRemoteSearch];
}

#pragma mark - Check

- (void)_checkIMAP {
	if (self.imapChecker) {
		return;
	}

	self.imapChecker = [[PSTAccountChecker alloc] init];
	if (self.MXProvider) {
		self.imapChecker.provider = [[MCOMailProvidersManager sharedManager] providerForIdentifier:[self MXProvider]];
	}
	[self.imapChecker setCheckerMask:PSTAccountCheckIMAP];
	[self.imapChecker setEmail:self.email];
	[self.imapChecker setPassword:self.password];
	[[self.imapChecker check]subscribeCompleted:^{
		[self _checkIMAPDone];
	}];
}

- (void)_checkIMAPDone {
	if (self.imapChecker.error == nil) {
		[self setImapService:self.imapChecker.imapService];
		[PSTAccountManager.defaultManager synchronize];
		[self applyChanges];
	}
	self.imapChecker = nil;
}

- (void)_progressSendMessageNext {
	self.sendMessagesNumberCurrentProgress += 1;
}

- (void)applyChanges {
	self.smtpAccount = nil;
	[_imapSynchronizer cancel];
}

#pragma mark - Delegate Methods

- (void)accountSynchronizerWillUpdateFolders:(PSTIMAPAccountSynchronizer *)synchronizer {
	_accountFlags.foldersUpdating = YES;
}

- (void)accountSynchronizerDidUpdateFolders:(PSTIMAPAccountSynchronizer *)synchronizer {
	PSTPropogateValueForKey(self.labels, { });
	_accountFlags.foldersUpdating = NO;
}

- (void)accountSynchronizerFetchedFolders:(PSTIMAPAccountSynchronizer *)synchronizer {
	NSSet *uniquingSet = [[NSSet alloc]initWithArray:synchronizer.folders];
	for (MCOIMAPFolder *folder in self.imapSynchronizer.folders) {
		for (NSString *ignoredPath in PSTIgnoredMailboxesArray) {
			if (![ignoredPath hasPrefix:@"[Google Mail]/"]) {
				if (![ignoredPath hasPrefix:@"[Gmail]/"]) {
					if (![ignoredPath isEqualToString:@"INBOX"]) {
						if (![uniquingSet containsObject:ignoredPath]) {
							NSRegularExpression *regexp = [[NSRegularExpression alloc]initWithPattern:[NSString stringWithFormat:@"^%@$", ignoredPath] options:0 error:nil];
							if ([regexp matchesInString:folder.path options:0 range:NSMakeRange(0, strlen(folder.path.UTF8String))].count != 0) {
								[self.hiddenLabels addObject:folder.path];
							}
						}
					}
				}
			}
		}
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[self _updateLabels];
	});
}

- (void)accountSynchronizerDidSetupAccount:(PSTIMAPAccountSynchronizer *)synchronizer {
	if (self.savedFolderPaths.count == 0) {
		return;
	}
	[_imapSynchronizer addFoldersWithPaths:self.savedFolderPaths];
}

- (void)accountSynchronizerDidUpdateLabels:(PSTIMAPAccountSynchronizer *)synchronizer {
	if (_accountFlags.foldersUpdating) {
		return;
	}
	[self _recreateLabelColors];
	PSTPropogateValueForKey(self.labels, { });
}

- (void)accountSynchronizerDidUpdateNamespace:(PSTIMAPAccountSynchronizer *)synchronizer {
	if (![self.namespacePrefix isEqualToString:_imapSynchronizer.namespacePrefix]) {
		self.namespacePrefix = _imapSynchronizer.namespacePrefix;
	}
	if (self.namespaceDelimiter == _imapSynchronizer.namespaceDelimiter) {
		[PSTAccountManager.defaultManager synchronize];
	}
	self.namespaceDelimiter = _imapSynchronizer.namespaceDelimiter;
}

- (void)accountSynchronizerDidUpdateXListMapping:(PSTIMAPAccountSynchronizer *)synchronizer {
	NSMutableSet *set = [NSMutableSet set];
	[set addObjectsFromArray:[self.xListMapping allKeys]];
	[set addObjectsFromArray:[_imapSynchronizer.xListMapping allKeys]];
	BOOL flag = ([set count] == _imapSynchronizer.xListMapping.count);
	BOOL otherFlag = NO;
	for (NSString *key in[self.xListMapping allKeys]) {
		otherFlag = NO;
		if ([[self.xListMapping objectForKey:key] isEqualToString:[_imapSynchronizer.xListMapping objectForKey:key]]) {
			otherFlag = flag;
		}
	}
	if (otherFlag == NO) {
		self.xListMapping = _imapSynchronizer.xListMapping;
		[PSTAccountManager.defaultManager synchronize];
	}
}

- (void)accountSynchronizerDidUpdateCount:(PSTIMAPAccountSynchronizer *)synchronizer {
	if (_accountFlags.waitingUntilAllOperationsHaveFinished == YES) {
		return;
	}
	[NSNotificationCenter.defaultCenter postNotificationName:PSTMailAccountCountUpdated object:self];
}

- (void)accountSynchronizerNeedsRefresh:(PSTIMAPAccountSynchronizer *)synchronizer {
	[self setSelected:synchronizer.selected];
	[synchronizer refreshSync];
}

- (void)accountSynchronizer:(PSTIMAPAccountSynchronizer *)synchronizer postNotificationForMessages:(NSArray *)messages conversationIDs:(NSArray *)conversationIDs {
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:messages forKey:PSTMessagesKey];
	[userInfo setObject:conversationIDs forKey:PSTConversationIDsKey];
	[NSNotificationCenter.defaultCenter postNotificationName:PSTMailAccountFetchedNewMessageNotification object:self userInfo:userInfo];
}

- (void)accountSynchronizerDidUpdateSearchResults:(PSTIMAPAccountSynchronizer *)synchronizer {
	PSTPropogateValueForKey(self.currentSearchResult, {});
}

#pragma mark - Reachability

- (NSDictionary *)folders {
	return [_imapSynchronizer folderMappingWithoutTrash];
}

#pragma mark - NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@:%p - %@>", [self class], self, self.email];
}

#pragma mark - Private

static NSSet *PSTMainFolderSetForProvider(MCOMailProvider *mailProvider) {
	NSMutableSet *folderSet = [[NSMutableSet alloc] init];
	NSString *sentMailPath = mailProvider.sentMailFolderPath;
	if (sentMailPath) {
		[folderSet addObject:sentMailPath];
	}
	NSString *starredPath = mailProvider.starredFolderPath;
	if (starredPath) {
		[folderSet addObject:starredPath];
	}
	NSString *allMailPath = mailProvider.allMailFolderPath;
	if (allMailPath) {
		[folderSet addObject:allMailPath];
	}
	NSString *trashPath = mailProvider.trashFolderPath;
	if (trashPath) {
		[folderSet addObject:trashPath];
	}
	NSString *draftsPath = mailProvider.draftsFolderPath;
	if (draftsPath) {
		[folderSet addObject:draftsPath];
	}
	NSString *spamPath = mailProvider.spamFolderPath;
	if (spamPath) {
		[folderSet addObject:spamPath];
	}
	NSString *importantPath = mailProvider.importantFolderPath;
	if (importantPath) {
		[folderSet addObject:importantPath];
	}
	return folderSet;
}

static MCOIMAPFolder *PSTFolderFromEnumInSynchronizer(PSTFolderType selection, PSTIMAPAccountSynchronizer *_imapSynchronizer, NSString *label) {
	switch (selection) {
		case PSTFolderTypeInbox: {
			return [_imapSynchronizer.session inboxFolder];
		}
			break;
		case PSTFolderTypeNextSteps: {
			return nil;
		}
			break;
		case PSTFolderTypeStarred: {
			return [_imapSynchronizer starredFolder];
		}
			break;
		case PSTFolderTypeDrafts: {
			return [_imapSynchronizer draftsFolder];
		}
			break;
		case PSTFolderTypeSent: {
			return [_imapSynchronizer sentMailFolder];
		}
			break;
		case PSTFolderTypeTrash: {
			return [_imapSynchronizer trashFolder];
		}
			break;
		case PSTFolderTypeSpam: {
			return [_imapSynchronizer spamFolder];
		}
			break;
		case PSTFolderTypeAllMail: {
			return [_imapSynchronizer allMailFolder];
		}
			break;
		case PSTFolderTypeImportant: {
			return [_imapSynchronizer importantFolder];
		}
			break;
		case PSTFolderTypeLabel: {
			if ([label isEqualToString:@"INBOX"]) {
				return _imapSynchronizer.inboxFolder;
			}
			return [_imapSynchronizer folderForPath:label];
		}
			break;
		default:
			break;
	}
	return nil;
}

@end
