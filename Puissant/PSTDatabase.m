//
//  PSTMessageDatabase.m
//  DotMail
//
//  Created by Robert Widmann on 10/13/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTDatabase.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "FMDatabaseQueue.h"
#import "PSTConversationCache.h"
#import "PSTIndexedMapTable.h"
#import "PSTLevelDBMapTable.h"
#import "PSTCache.h"
#import "NSString+PSTURL.h"
#import "PSTCachedMessage.h"
#import "NSData+PSTGZip.h"
#import "PSTLocalMessage.h"
#import "PSTArchiver.h"
#import "NSString+PSTFilenames.h"
#import "NSData+PSTCompression.h"
#import "PSTConversation.h"
#import "NSString+PSTUUID.h"
#import "PSTLocalAttachment.h"
#import "NSString+HTML.h"
#import "NSString+PSTURL.h"
#import "PSTAttachmentCache.h"
#import "MCOAbstractMessage+LEPRecursiveAttachments.h"
#import "MCOAbstractPart+LEPRecursiveAttachments.h"
#import "MCOMessageHeader+PSTExtensions.h"
#import "MCOIMAPMessage+PSTExtensions.h"
#import "PSTConstants.h"
#import "PSTSerializableMessage.h"
#import "PSTMessageIndex.h"
#import "NSString+PSTSearch.h"

static NSArray *statements = nil;

#ifdef DEBUG
#define PUISSANT_FMDB_ERROR_LOG \
if ([self.connection hadError]) { \
PSTLog(@"%d: PSTMessageDatabase error %d: %@", __LINE__, [self.connection lastErrorCode], [self.connection lastErrorMessage]); \
}
#else 
#define PUISSANT_FMDB_ERROR_LOG 
#endif 

@interface PSTDatabase ()
@property (atomic, strong) FMDatabase *connection;

@property (atomic, strong) PSTIndexedMapTable *conversationsCache;
@property (atomic, strong) PSTIndexedMapTable *messagesCache;
@property (atomic, strong) PSTLevelDBMapTable *plainTextCache;
@property (atomic, strong) PSTLevelDBMapTable *flagsCache;
@property (atomic, strong) PSTLevelDBMapTable *labelsCache;
@property (strong) PSTLevelDBMapTable *previewCache;

@property (atomic, strong) PSTMessageIndex *index;

@property (nonatomic, strong) PSTCache *decodedMessageCache;
@property (nonatomic, strong) PSTCache *oldestUIDForFolderCache;

@property (nonatomic, strong) NSMutableDictionary *folderIdentifiersCache;
@property (nonatomic, strong) NSMutableDictionary *folderPaths;
@property (nonatomic, strong) NSMutableDictionary *folderCounts;
@property (nonatomic, strong) NSMutableDictionary *folderUnreadCounts;
@property (nonatomic, strong) NSMutableDictionary *incompleteUIDsPathways;
@property (nonatomic, strong) NSMutableDictionary *lastUIDPathDict;
@property (nonatomic, strong) NSMutableSet *uidsModified;
@property (nonatomic, strong) NSMutableDictionary *pendingConversationCache;
@property (nonatomic, strong) NSMutableIndexSet *invalidConversationRowIDs;
@property (nonatomic, strong) NSMutableSet *invalidConversationMessageIDs;
@property (nonatomic, strong) NSMutableDictionary *lastNotifiedUIDs;
@property (nonatomic, strong) NSMutableDictionary *duplicates;
@property (nonatomic, strong) NSArray *pendingFoldersIdentifiers;

@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, copy, readonly) NSString *email;
@property (nonatomic, copy, readonly) NSString *localDraftsPath;

@property (nonatomic, assign) NSUInteger starredCount;
@property (nonatomic, assign) NSUInteger nextStepCount;
@end

@implementation PSTDatabase {
	struct {
		PSTDatabaseType databaseType;
		unsigned int validateFolderStarted:1;
		unsigned int validateFolderCancelled:1;
		unsigned int cancelConversations:1;
		unsigned int conversationsStarted:1;
		unsigned int conversationAllMessageIDsInvalid:1;
		unsigned int conversationRowIDAdded:1;
	} _databaseFlags;
}

+ (void)initialize {
	if (self == PSTDatabase.class) {
		if (statements == nil) {
			statements = @[
				@"create table mailbox (path text, uidvalidity number, unseen_count number, count number, oldest_uid number);",
				@"create index path_index on mailbox(path);",
				@"create table message (uid number, msgid text, folder_idx number, date date, flags number, original_flags number, conversation_id number, flags_dirty number, deleted number, is_flagged number, is_read number, is_deleted number, is_notified number, is_local number, is_facebook number, is_twitter number);",
				@"create index message_uid_index on message (uid, folder_idx);",
				@"create index message_msgid_index on message (msgid);",
				@"create index message_conversation_id_index on message (conversation_id);",
				@"create index message_read_idx on message (folder_idx, is_read);",
				@"create index message_flags_idx on message (folder_idx, is_flagged, is_read, is_deleted);",
				@"create table message_relation (thread_id number, msgid text);",
				@"create table conversation_thread_id (thread_id number, conversation_id number);",
				@"create index conversation_thread_id_index on conversation_thread_id(thread_id);",
				@"create table conversation (preview_subject text, subject text);",
				@"create table conversation_data (conversation_id number, folder_idx number, most_recent_message_date date, visible number, action_step number, is_facebook number, is_twitter number);",
				@"create index conversation_data_conversation_id_folder_idx_idx on conversation_data (conversation_id, folder_idx);",
				@"create index conversation_data_folder_index on conversation_data (folder_idx, visible);",
				@"create index conversation_data_conversation_id_idx on conversation_data (conversation_id);",
				@"create table attachment (folder_idx number, message_id number, part_id text, filepath text, filename text, is_body_attachment number, contents blob, has_contents number, uid number);",
				@"create index attachment_message_index on attachment (message_id);",
				@"create index attachment_part_id_index on attachment (message_id, part_id);",
				@"create index attachment_contents_index on attachment (folder_idx, has_contents);",
			];
		}
	}
}

#pragma mark - Lifecycle

+ (instancetype)databaseForEmail:(NSString *)email withPath:(NSString *)path type:(PSTDatabaseType)type {
	return [[self alloc] initWithEmail:email andPath:path type:type];
}

- (id)init {
	self = [super init];
	
	_folderIdentifiersCache = @{}.mutableCopy;
	_folderPaths = @{}.mutableCopy;
	_folderCounts = @{}.mutableCopy;
	_folderUnreadCounts = @{}.mutableCopy;
	_incompleteUIDsPathways = @{}.mutableCopy;
	_lastUIDPathDict = @{}.mutableCopy;
	_incompleteUIDsPathways = @{}.mutableCopy;
	_uidsModified = [[NSMutableSet alloc]init];
	_starredCount = NSUIntegerMax;
	_decodedMessageCache = [[PSTCache alloc]init];
	_pendingConversationCache = @{}.mutableCopy;
	_invalidConversationRowIDs = [[NSMutableIndexSet alloc]init];
	_invalidConversationMessageIDs = [[NSMutableSet alloc]init];
	_lastNotifiedUIDs = @{}.mutableCopy;
		
	return self;
}

- (id)initWithEmail:(NSString *)email andPath:(NSString *)path type:(PSTDatabaseType)type {
	self = [self init];
	
	_email = email;
	_localDraftsPath = @"~/Library/Application Support/DotMail/Drafts".stringByExpandingTildeInPath;
	_path = path;
	_databaseFlags.databaseType = type;

	return self;
}

- (void)initializeWithCachesForConversations:(PSTIndexedMapTable *)c messages:(PSTIndexedMapTable *)m previews:(PSTLevelDBMapTable *)p text:(PSTLevelDBMapTable *)t flags:(PSTLevelDBMapTable *)f labels:(PSTLevelDBMapTable *)l {
	_conversationsCache = c;
	_messagesCache = m;
	_previewCache = p;
	_plainTextCache = t;
	_flagsCache = f;
	_labelsCache = l;
}

#pragma mark - Main Interface

- (BOOL)open {
	if (_databaseFlags.databaseType != PSTDatabaseTypeSerial) {
		return YES;
	}
	BOOL retval = YES;
	NSString *messagesDBPath = [self.path stringByAppendingPathComponent:@"messages.db"];
	self.connection = [FMDatabase databaseWithPath:messagesDBPath];
	BOOL msgDatabaseExists = [[NSFileManager defaultManager]fileExistsAtPath:messagesDBPath];
	if ([self.connection open]) {
		NSString *columnString = nil;
		if ([self.connection open]) {
			FMResultSet *resultSet = [self.connection executeQuery:@"PRAGMA journal_mode"];
			if ([resultSet next]) {
				columnString = [[[resultSet stringForColumnIndex:0]lowercaseString]copy];
			}
			[resultSet close];
			
			if (![columnString isEqualToString:@"wal"]) {
				FMResultSet *resultSet = [self.connection executeQuery:@"PRAGMA journal_mode=WAL"];
				[resultSet close];
			}
			columnString = nil;
			[self.connection setShouldCacheStatements:YES];
			[self.connection executeUpdate:@"PRAGMA synchronous = NORMAL"];
			[self.connection executeUpdate:@"PRAGMA cache_size = 100"];
			
			if (!msgDatabaseExists) {
				if ([self _setupDatabase]) {
					[[NSFileManager defaultManager]createDirectoryAtPath:self.localDraftsPath withIntermediateDirectories:YES attributes:nil error:nil];
				}
				return YES;
			}
			return YES;
		}
		//**VERSION CHECK**
		//		FMResultSet *resultSet = [self.database executeQuery:@"PRAGMA user_version"];
		//		if ([resultSet next]) {
		//			[resultSet intForColumnIndex:0];
		//		}
		//		[resultSet close];
		//		[self.database close];
		//		return retval;
		
	}
	NSAssert(nil, @"A Database was not created for this account");
	[self.connection close];
	self.connection = nil;
	retval = NO;
	return retval;
}

- (void)openIndex {
	_index = [[PSTMessageIndex alloc] init];
	_index.database = _connection;
	_index.path = _path;
	_index.delegate = self;
	if ([_index openAndCheckConsistency]) {
		[_index close];
		_index = nil;
	}
}

- (BOOL)_setupDatabase {
	[self.connection executeUpdate:@"PRAGMA user_version = 1"];
	PUISSANT_FMDB_ERROR_LOG
	[self _executeSQLArray:statements];
	return YES;
}

- (void)_executeSQLArray:(NSArray *)statements {
	for (NSString *substring in statements) {
		[self.connection executeUpdate:substring];
		if ([self.connection hadError]) {
			PSTLog(@"error executing substring: \n%@\n", substring);
			PUISSANT_FMDB_ERROR_LOG
		}
	}
}

- (void)close {
	[self.connection close];
	self.connection = nil;
}


- (void)beginTransaction {
	[self.connection beginTransaction];
	@synchronized(self) {
		[self.decodedMessageCache beginTransaction];
	}
}

- (void)commit {
	[self.connection commit];
	for (NSNumber *messageUID in self.pendingConversationCache) {
		id conversation = [self.pendingConversationCache objectForKey:messageUID];
		[self.conversationsCache setData:[NSKeyedArchiver archivedDataWithRootObject:conversation] forIndex:[messageUID longLongValue]];
	}
	[self.pendingConversationCache removeAllObjects];
	@synchronized(self) {
		[self.decodedMessageCache endTransaction];
	}
}

- (void)commitMessageUIDs {
	for (NSString *path in [self.uidsModified allObjects]) {
		[self _saveMessagesUIDsForPath:path];
	}
}

#pragma mark - Folders and Identifiers


- (void)warmFolderIdentifiersCache {
	NSMutableDictionary *cachedFolderIdentifiers = [NSMutableDictionary dictionary];
	NSMutableDictionary *cachedFolderPaths = [NSMutableDictionary dictionary];
	
	FMResultSet *result = [self.connection executeQuery:@"select rowid, path from mailbox"];
	while ([result next]) {
		[cachedFolderIdentifiers setObject:[NSNumber numberWithLongLong:[result longLongIntForColumn:@"rowid"]] forKey:[result stringForColumn:@"path"]];
		[cachedFolderPaths setObject:[result stringForColumn:@"path"] forKey:[NSNumber numberWithLongLong:[result longLongIntForColumn:@"rowid"]]];
	}
	[result close];
	@synchronized(self) {
		[self.folderIdentifiersCache addEntriesFromDictionary:cachedFolderIdentifiers];
		[self.folderPaths addEntriesFromDictionary:cachedFolderPaths];
	}
}

- (void)defrostFolderIdentifiersWithDictionary:(NSDictionary *)foldersMapping {
	@synchronized(self) {
		[self.folderPaths removeAllObjects];
		[self.folderIdentifiersCache removeAllObjects];
		for (id key in [foldersMapping allKeys]) {
			[self.folderPaths setObject:[foldersMapping objectForKey:key] forKey:key];
			[self.folderIdentifiersCache setObject:key forKey:[foldersMapping objectForKey:key]];
		}
	}
}

- (NSUInteger)addFolder:(NSString *)folderPath {
	NSUInteger retVal = [self _folderIdentifierForPath:folderPath];
	if (retVal == NSUIntegerMax) {
		[self.connection executeUpdate:@"insert into mailbox (path, unseen_count, count) values (?, 0, 0)", folderPath];
		PUISSANT_FMDB_ERROR_LOG
		@synchronized(self) {
			[self.folderIdentifiersCache setObject:[NSNumber numberWithLongLong:[self.connection lastInsertRowId]] forKey:folderPath];
			[self.folderPaths setObject:folderPath forKey:[NSNumber numberWithLongLong:[self.connection lastInsertRowId]]];
		}
		retVal = [self.connection lastInsertRowId];
	}
	else {
		retVal = [self _folderIdentifierForPath:folderPath];
	}
	return retVal;
}

- (NSUInteger)countOfMessagesAtPath:(NSString *)path {
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
	FMResultSet *queryResults = [self.connection executeQuery:@"select count(*) from message where folder_idx = ?", @(folderIdentifier)];
	__block NSInteger count = 0;
	if ([queryResults next]) {
		count = [queryResults intForColumnIndex:0];
	}
	[queryResults close];
	NSMutableIndexSet *incompletes = [self _incompleteMessagesUIDsIndexSetForPath:path];
	[incompletes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		if (count <= idx) {
			count++;
		}
	}];
	return count;
}

- (NSUInteger)identifierForFolderPath:(NSString *)path {
	return [self _folderIdentifierForPath:path];
}

- (NSUInteger)_folderIdentifierForPath:(NSString *)path {
	NSUInteger retVal = NSUIntegerMax;
	if (path == nil) return retVal;
	
	@synchronized(self) {
		NSNumber *identifier = self.folderIdentifiersCache[path];
		if (identifier != nil) {
			retVal = [identifier longLongValue];
		}
	}
	if (retVal == NSUIntegerMax) {
		if ([NSThread currentThread] != [NSThread mainThread]) {
			FMResultSet *resultSet = [self.connection executeQuery:@"select rowid from mailbox where path = ?", path];
			if (![resultSet next]) {
				[resultSet close];
				retVal = NSUIntegerMax;
			}
			else {
				retVal = NSUIntegerMax;
				NSUInteger identifier = [resultSet longLongIntForColumn:@"rowid"];
				if ([resultSet longLongIntForColumn:@"rowid"] != NSUIntegerMax) {
					@synchronized(self) {
						[self.folderIdentifiersCache setObject:[NSNumber numberWithLongLong:identifier] forKey:path];
						[self.folderPaths setObject:path forKey:[NSNumber numberWithLongLong:identifier]];
						retVal = identifier;
					}
				}
			}
		} else {
			PSTLog(@"failed getting path %@ %@", self.email, path);
			retVal = NSUIntegerMax;
		}
	}
	return retVal;
}

- (NSString *)folderPathForIdentifier:(NSUInteger)identifier {
	NSString *path;
	@synchronized(self) {
		path = [self.folderPaths objectForKey:[NSNumber numberWithUnsignedInteger:identifier]];
	}
	if (path == nil) {
		if ([NSThread currentThread] == [NSThread mainThread]) {
			PSTLog(@"failed getting path for identifier %@ %lu", self.email, identifier);
			path = nil;
		}
		else {
			FMResultSet *query =[self.connection executeQuery:@"select path from mailbox where rowid = ?", [NSNumber numberWithUnsignedInteger:identifier]];
			if ([query next]) {
				path = [query stringForColumn:@"path"];
			}
			[query close];
			if (path != nil) {
				@synchronized(self) {
					[self.folderIdentifiersCache setObject:[NSNumber numberWithUnsignedInteger:identifier] forKey:path];
					[self.folderPaths setObject:path forKey:[NSNumber numberWithUnsignedInteger:identifier]];
				}
			}
		}
	}
	return path;
}

- (NSDictionary *)foldersIdentifiersMap {
	NSDictionary *retVal = nil;
	@synchronized(self) {
		retVal = [self.folderPaths copy];
	}
	return retVal;
}

#pragma mark - Message Operations

- (void)addMessageUID:(NSUInteger)uid forPath:(NSString *)path {
	[[self _incompleteMessagesUIDsIndexSetForPath:path]addIndex:uid];
	[self.uidsModified addObject:path];
}

- (BOOL)addMessage:(MCOIMAPMessage *)message inFolder:(NSString *)folderPath {
	NSUInteger rowID = [self indexOfMessage:message atPath:folderPath];
	BOOL result = NO;
	if (rowID == NSUIntegerMax) {
		if (message.header.messageID == nil) {
			[message.header setMessageID:[NSString dmUUIDString]];
		}
		if (folderPath == nil) {
			return result;
		}
		NSUInteger folderIdentifier = [self _folderIdentifierForPath:folderPath];
		if (folderIdentifier == NSUIntegerMax) {
			return result;
		}
		[self removeMessageUIDFromIncomplete:((MCOIMAPMessage *)message).uid forPath:folderPath];
		
		MCOMessageFlag messageFlags = message.flags;
		BOOL isSeen = (messageFlags & MCOMessageFlagSeen);
		BOOL isFlagged = (messageFlags & MCOMessageFlagFlagged);
		BOOL isDeleted = (messageFlags & MCOMessageFlagDeleted);
		[self.connection executeUpdate:@"insert into message (msgid, date, original_flags, flags, uid, folder_idx, flags_dirty, deleted, is_read, is_flagged, is_deleted, is_notified, is_local, is_facebook, is_twitter) values (?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, 0, 0, ?, ?)", message.header.messageID, message.header.receivedDate, @(((MCOIMAPMessage *)message).originalFlags), @(messageFlags), @(((MCOIMAPMessage *)message).uid), @(folderIdentifier), @(isSeen), @(isFlagged), @(isDeleted), @(message.isFacebookNotification), @(message.isTwitterNotification)];
		PUISSANT_FMDB_ERROR_LOG
		NSUInteger lastMessageInsertRowID = self.connection.lastInsertRowId;
		[self cacheMessage:message atRowIndex:lastMessageInsertRowID];
		if ([message isKindOfClass:[MCOIMAPMessage class]]) {
			for (MCOIMAPMessagePart *attachment in [message allAttachments]) {
				[self.connection executeUpdate:@"insert into attachment (folder_idx, message_id, uid, part_id, is_body_attachment, has_contents, filename, filepath) values (?, ?, ?, ?, 0, 0, ?, null)", @(folderIdentifier), @(lastMessageInsertRowID), @(((MCOIMAPMessage *)message).uid), attachment.partID, attachment.filename];
				PUISSANT_FMDB_ERROR_LOG
			}
			for (MCOIMAPMessagePart *attachment in [message attachmentsWithContentIDs]) {
				[self.connection executeUpdate:@"insert into attachment (folder_idx, message_id, uid, part_id, is_body_attachment, has_contents, filename, filepath) values (?, ?, ?, ?, 0, 0, ?, null)", @(folderIdentifier), @(lastMessageInsertRowID), @(((MCOIMAPMessage *)message).uid), attachment.partID, attachment.filename];
				PUISSANT_FMDB_ERROR_LOG
			}
			for (MCOIMAPMessagePart *attachment in [message htmlInlineAttachments]) {
				[self.connection executeUpdate:@"insert into attachment (folder_idx, message_id, uid, part_id, is_body_attachment, has_contents, filename, filepath) values (?, ?, ?, ?, ?, 0, null, null)", @(folderIdentifier), @(lastMessageInsertRowID), @(((MCOIMAPMessage *)message).uid), attachment.partID, @YES];
				PUISSANT_FMDB_ERROR_LOG
			}
			if (((MCOIMAPMessage *)message).attachments == nil) {
				[self.connection executeUpdate:@"insert into attachment (folder_idx, message_id, uid, part_id, is_body_attachment, has_contents, filename, filepath) values (?, ?, ?, null, 1, 0, null, null)", @(folderIdentifier), @(lastMessageInsertRowID), @(((MCOIMAPMessage *)message).uid)];
				PUISSANT_FMDB_ERROR_LOG
			}
		}
		
		if ([message isKindOfClass:[MCOPOPMessageInfo class]]) {
			
		}
		NSMutableSet *relationsSet = [[NSMutableSet alloc]init];
		[relationsSet addObjectsFromArray:message.header.references];
		[relationsSet addObjectsFromArray:message.header.inReplyTo];
		[relationsSet addObject:message.header.messageID];
		NSArray *relations = [relationsSet allObjects];
		NSMutableSet *set = [[NSMutableSet alloc]init];
		NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc]init];
		NSMutableArray *array2 = [[NSMutableArray alloc]init];
		NSUInteger relationID = NSUIntegerMax;
		for (NSString *relation in relations) {
			FMResultSet *relationQuery = [self.connection executeQuery:@"select thread_id from message_relation where msgid = ?", message.header.messageID];
			if (![relationQuery next]) {
				[relationQuery close];
				continue;
			}
			[set addObject:relation];
			long long potentialRelationID = [relationQuery longLongIntForColumn:@"thread_id"];
			if (![indexSet containsIndex:potentialRelationID]) {
				[indexSet addIndex:potentialRelationID];
				if (relationID == NSUIntegerMax) {
					relationID = potentialRelationID;
				}
				[array2 addObject:@(potentialRelationID)];
			}
			[relationQuery close];
		}
		if (relationID == NSUIntegerMax) {
			return [self createConversationRelationForMessage:message inFolder:folderIdentifier rowID:rowID
												   relationID:relationID relations:relations lastInsert:lastMessageInsertRowID]
			&& [self generatePreviewForMessage:message atPath:folderPath];
		}
		for (NSNumber *relationNumber in array2) {
			[self.connection executeUpdate:@"update message_relation set thread_id = ? where thread_id = ?", @(relationID), relationNumber];
			PUISSANT_FMDB_ERROR_LOG
		}
		for (NSNumber *relationNumber in array2) {
			[self.connection executeUpdate:@"update conversation_thread_id set thread_id = ? where thread_id = ?", @(relationID), relationNumber];
			PUISSANT_FMDB_ERROR_LOG
		}
		NSUInteger convoMergeID = NSUIntegerMax;
		NSMutableArray *conversationsToMerge = [[NSMutableArray alloc]init];
		FMResultSet *convoIDQuery = [self.connection executeQuery:@"select conversation_id, preview_subject from conversation_thread_id,conversation where thread_id = ? and conversation_id = conversation.rowid", @(lastMessageInsertRowID)];
		PUISSANT_FMDB_ERROR_LOG
		while ([convoIDQuery next]) {
			if ([convoIDQuery stringForColumn:@"preview_subject"].length == 0) {
				continue;
			}
			long long conversationID = [convoIDQuery longLongIntForColumn:@"conversation_id"];
			if (convoMergeID == NSUIntegerMax) {
				convoMergeID = conversationID;
			} else {
				[conversationsToMerge addObject:@(conversationID)];
			}
		}
		[convoIDQuery close];
		[self _mergeIntoConversation:convoMergeID conversations:conversationsToMerge];
		if (relationID == NSUIntegerMax) {
			relationID = lastMessageInsertRowID;
		}
		for (NSString *relation in relations) {
			[self.connection executeUpdate:@"insert into message_relation (thread_id, msgid) values (?, ?)", @(relationID), message.header.messageID];
			PUISSANT_FMDB_ERROR_LOG
		}
		return [self createConversationRelationForMessage:message inFolder:folderIdentifier rowID:rowID
											   relationID:relationID relations:relations lastInsert:lastMessageInsertRowID]
		&& [self generatePreviewForMessage:message atPath:folderPath];
	}
	[self removeMessageUIDFromIncomplete:message.uid forPath:folderPath];
	result = NO;
	return result;
}

- (BOOL)createConversationRelationForMessage:(MCOIMAPMessage *)message inFolder:(NSInteger)folderIdentifier rowID:(NSInteger)rowID relationID:(NSInteger)relationID relations:(NSArray *)relations lastInsert:(NSInteger)lastMessageInsertRowID {
	BOOL result = YES;
	if (relationID == NSUIntegerMax) {
		relationID = lastMessageInsertRowID;
	}
	for (NSString *relation in relations) {
		[self.connection executeUpdate:@"insert into message_relation (thread_id, msgid) values (?, ?)", @(relationID), message.header.messageID];
		PUISSANT_FMDB_ERROR_LOG
	}
	NSString *extractedSubject = [message.header.extractedSubject lowercaseString];
	NSUInteger lastConversationInsertRowID = NSUIntegerMax;
	FMResultSet *queryResults = [self.connection executeQuery:@"select rowid, preview_subject from conversation where rowid in (select distinct conversation_id from conversation_thread_id where thread_id = ?)", @(relationID)];
	while ([queryResults next]) {
		lastConversationInsertRowID = [queryResults longLongIntForColumn:@"rowid"];
		if ([queryResults stringForColumn:@"preview_subject"] != nil) {
			extractedSubject = [queryResults stringForColumn:@"preview_subject"];
		}
		if (![extractedSubject isEqualToString:@""]) {
			continue;
		}
	}
	[queryResults close];
	if (lastConversationInsertRowID == NSUIntegerMax) {
		[self.connection executeUpdate:@"insert into conversation (preview_subject, subject) values (?, ?)", extractedSubject, message.header.subject];
		PUISSANT_FMDB_ERROR_LOG
		lastConversationInsertRowID = self.connection.lastInsertRowId;
		[self.connection executeUpdate:@"update message set conversation_id = ? where rowid = ?", @(lastConversationInsertRowID), @(lastMessageInsertRowID)];
		PUISSANT_FMDB_ERROR_LOG
		[self.connection executeUpdate:@"insert into conversation_thread_id (thread_id, conversation_id) values (?, ?)", @(relationID), @(lastConversationInsertRowID)];
		PUISSANT_FMDB_ERROR_LOG
	} else {
		[self.connection executeUpdate:@"update message set conversation_id = ? where rowid = ?", @(lastConversationInsertRowID), @(lastMessageInsertRowID)];
		PUISSANT_FMDB_ERROR_LOG
	}
	[self _resetDiffingState];
	_databaseFlags.conversationRowIDAdded = 1;
	[self.invalidConversationRowIDs addIndex:rowID];
	[self _updateConversationVisibility:lastConversationInsertRowID folderID:folderIdentifier];
	
	//	NSString *fromString = @"";
	//	if (message.header.from.displayName != nil) {
	//		fromString = [[NSString alloc] initWithFormat:@"%@ %@ ", message.header.from.displayName, message.header.from.mailbox];
	//	} else {
	//		fromString = [[NSString alloc] initWithFormat:@"%@ ", message.header.from.mailbox];
	//	}
	//	NSMutableString *recipients = [[NSMutableString alloc] init];
	//	for (MCOAddress *toAddress in message.header.to) {
	//		if (toAddress.displayName != nil) {
	//			[recipients appendFormat:@"%@ %@", toAddress.displayName, toAddress.mailbox];
	//		} else {
	//			[recipients appendFormat:@"%@", toAddress.mailbox];
	//		}
	//	}
	//	for (MCOAddress *toAddress in message.header.cc) {
	//		if (toAddress.displayName != nil) {
	//			[recipients appendFormat:@"%@ %@", toAddress.displayName, toAddress.mailbox];
	//		} else {
	//			[recipients appendFormat:@"%@", toAddress.mailbox];
	//		}
	//	}
	//	for (MCOAddress *toAddress in message.header.bcc) {
	//		if (toAddress.displayName != nil) {
	//			[recipients appendFormat:@"%@ %@", toAddress.displayName, toAddress.mailbox];
	//		} else {
	//			[recipients appendFormat:@"%@", toAddress.mailbox];
	//		}
	//	}
	return result;
}


- (void)_mergeIntoConversation:(NSUInteger)conversationID conversations:(NSArray *)conversations {
	for (NSNumber *convoID in conversations) {
		[self.connection executeUpdate:@"update message set conversation_id = ? where conversation_id = ?", @(conversationID), convoID];
		PUISSANT_FMDB_ERROR_LOG
		[self.connection executeUpdate:@"delete from conversation where rowid = ?", convoID];
		PUISSANT_FMDB_ERROR_LOG
		[self.conversationsCache removeDataForIndex:[convoID longLongValue]];
		[self.pendingConversationCache removeObjectForKey:convoID];
		[self.connection executeUpdate:@"update conversation_thread_id set conversation_id = ? where thread_id = ?", @(conversationID), convoID];
		PUISSANT_FMDB_ERROR_LOG
		[self.connection executeUpdate:@"delete from conversation_data where conversation_id = ?", convoID];
		PUISSANT_FMDB_ERROR_LOG
	}
}

- (void)setContent:(NSData *)data forMessage:(MCOAbstractMessage *)message inFolder:(NSString *)path {
	if (data != nil) {
		[self.plainTextCache setData:data forKey:PSTIdentifierForAttachmentWithPath(message, @"full", path)];
	}
	NSUInteger rowID = [self indexOfMessage:message atPath:path];
	[self.connection executeUpdate:@"update attachment set has_contents = 1 where message_id = ?", @(rowID)];
	if ([self.connection hadError]) {
		PSTLog(@"PSTMessageDatabase error %d: %@", [self.connection lastErrorCode], [self.connection lastErrorMessage]);
	}
	[self _generatePreviewForMessage:message atPath:path];
}

- (void)addAttachment:(MCOAbstractMessage *)message inFolder:(NSString *)path partID:(NSString *)part_id filename:(NSString *)filename data:(NSData *)data mimeType:(NSString *)mimeType {
	NSUInteger rowID = [self indexOfMessage:message atPath:path];
	NSString *attachmentFilename = @"";
	if ([[mimeType lowercaseString]isEqualToString:@"text/plain"] || [[mimeType lowercaseString]isEqualToString:@"text/html"]) {
		if (data != nil) {
			[self.plainTextCache setData:data forKey:PSTIdentifierForAttachmentWithPath(message, part_id, path)];
		}
	} else {
		attachmentFilename = [self _filenameForAttachment:message atPath:path partID:part_id filename:filename mimeType:mimeType];
		[[NSFileManager defaultManager]createDirectoryAtPath:[attachmentFilename stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
		if (data != nil) {
			[data writeToFile:attachmentFilename atomically:YES];
		}
	}
	[self.connection executeUpdate:@"update attachment set has_contents = 1, filepath = ? where message_id = ? and part_id = ?", attachmentFilename, @(rowID), part_id];
	PUISSANT_FMDB_ERROR_LOG
	[self _generatePreviewForMessage:message atPath:path];
}

- (NSIndexSet *)messagesUIDsNotInDatabase:(NSArray *)messages forPath:(NSString *)path {
	NSMutableString *queryString = [NSMutableString stringWithString:@"select uid from message where folder_idx = ? and uid in ("];
	long long int index = messages.count - 1;
	long long int counter = 0;
	for (MCOIMAPMessage *message in messages) {
		[queryString appendString:[@(message.uid) stringValue]];
		if (counter < index) {
			[queryString appendString:@","];
		} else {
			[queryString appendString:@")"];
		}
		counter++;
	}
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
	FMResultSet *uidResult = [self.connection executeQuery:queryString, @(folderIdentifier)];
	NSMutableIndexSet *set = [[NSMutableIndexSet alloc]init];
	NSMutableIndexSet *indexset = [[NSMutableIndexSet alloc]init];
	if ([uidResult next]) {
		while ([uidResult next]) {
			[indexset addIndex:[uidResult longLongIntForColumnIndex:0]];
		}
	}
	[uidResult close];
	for (MCOIMAPMessage *message in messages) {
		if (![indexset containsIndex:message.uid]) {
			[set addIndex:message.uid];
		}
	}
	return set;
}


- (NSIndexSet *)messagesUIDsSetForPath:(NSString *)path {
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
	FMResultSet *resultSet = [self.connection executeQuery:@"select uid from message indexed by message_uid_index where folder_idx = ? and is_local = 0 order by uid asc", @(folderIdentifier)];
	if ([resultSet next]) {
		while ([resultSet next]) {
			[indexSet addIndex:[resultSet longLongIntForColumn:@"uid"]];
		}
	}
	[resultSet close];
	return indexSet;
}

- (void)removeMessagesWithMessageID:(NSString *)msgID path:(NSString *)folderPath {
	FMResultSet *queryResult = nil;
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:folderPath];
	
	[self.connection executeUpdate:@"update message set deleted = 2 where msgid = ? and folder_idx = ? and is_local = 0", msgID, @(folderIdentifier)];
	PUISSANT_FMDB_ERROR_LOG
	queryResult = [self.connection executeQuery:@"select conversation_id from message where msgid = ? and folder_idx = ? and is_local = 0", msgID, @(folderIdentifier)];
	while ([queryResult next]) {
		[self _resetDiffingState];
		NSUInteger convoID = [queryResult longLongIntForColumn:@"conversation_id"];
		[self.invalidConversationMessageIDs addObject:@(convoID)];
		[self _updateConversationVisibility:convoID folderID:folderIdentifier];
	}
	[queryResult close];
}

- (void)removeLocalDraftMessageID:(NSString *)msgID path:(NSString *)path {
	[self removeLocalDraftMessageID:msgID path:path beforeDate:nil];
}

- (void)removeMessage:(MCOAbstractMessage *)message atPath:(NSString *)folderPath {
	if (![message isKindOfClass:[MCOIMAPMessage class]]) {
		if (![message isKindOfClass:[PSTLocalMessage class]]) {
			//WTF
		} else {
			[self removeLocalDraftMessageID:[(PSTLocalMessage *)message header].messageID path:[(PSTLocalMessage *)message folder].path];
		}
	} else {
		[self removeMessageUID:[(MCOIMAPMessage *)message uid] path:folderPath];
	}
}

- (NSData *)dataForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path {
	return [self.plainTextCache dataForKey:PSTIdentifierForAttachmentWithPath(message, @"full", path)];
}

- (BOOL)hasDataForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	return [self.plainTextCache hasDataForKey:PSTIdentifierForAttachmentWithPath(message, @"full", path)];
}

- (NSDictionary *)messagesNeedingNotificationForFolder:(MCOIMAPFolder *)folder {
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:folder.path];
	NSNumber *lastNotifiedUID = [self.lastNotifiedUIDs objectForKey:@(folderIdentifier)];
	NSMutableArray *newMessagesToNotify = [[NSMutableArray alloc]init];
	NSMutableArray *oldMessagesToNotify = [[NSMutableArray alloc]init];
	NSMutableArray *messagesArray = [[NSMutableArray alloc]init];
	NSMutableArray *conversationIDs = [[NSMutableArray alloc]init];
	FMResultSet *query = [self.connection executeQuery:@"select uid,rowid,conversation_id from message indexed by message_flags_idx where is_notified = 0 and is_read = 0 and folder_idx = ?", @(folderIdentifier)];
	@autoreleasepool {
		while ([query next]){
			long long rowID = [query longLongIntForColumn:@"rowid"];
			PSTSerializableMessage *result = [self lookupCachedMessageAtRowIndex:rowID];
			if (result == nil) {
				continue;
			} else {
				long long conversationID = [query longLongIntForColumn:@"conversation_id"];
				[result dm_setFolder:folder];
				if (result.uid > [lastNotifiedUID longLongValue]) {
					[messagesArray addObject:result];
					[conversationIDs addObject:@(conversationID)];
					[newMessagesToNotify addObject:@(rowID)];
				} else {
					[oldMessagesToNotify addObject:@(rowID)];
				}
			}
		}
	}
	[query close];
	long long lastUID = [lastNotifiedUID longLongValue];
	query = [self.connection executeQuery:@"select uid from message where folder_idx = ? order by uid desc limit 1", @(folderIdentifier)];
	if ([query next]) {
		long long uid = [query longLongIntForColumn:@"uid"];
		if (uid > lastUID) {
			lastUID = uid;
		}
	}
	[query close];
	if (messagesArray.count <= 2) {
		int counter = 0;
		while (counter < messagesArray.count) {
			MCOAbstractMessage *message = [messagesArray objectAtIndex:counter];
			if (![self hasPreviewForMessage:message atPath:folder.path]) {
				uint32_t uid = ((MCOIMAPMessage *)message).uid;
				if (uid != 0) {
					if ((uid - 1) < lastUID) {
						lastUID = (uid - 1);
					}
				}
				[messagesArray removeObjectAtIndex:counter];
				
			} else {
				counter++;
			}
		}
	}
	if (lastNotifiedUID != nil) {
		[self.lastNotifiedUIDs setObject:@(lastUID) forKey:@(folderIdentifier)];
	}
	NSMutableDictionary *retVal = [[NSMutableDictionary alloc]init];
	[retVal setObject:messagesArray forKey:@"Messages"];
	[retVal setObject:conversationIDs forKey:@"ConversationIDs"];
	for (NSNumber *rowID in newMessagesToNotify) {
		[self.connection executeUpdate:@"update message set is_notified = 1 where rowid = ?", rowID];
	}
	for (NSNumber *rowID in oldMessagesToNotify) {
		[self.connection executeUpdate:@"update message set is_notified = 1 where rowid = ?", rowID];
	}
	return retVal;
}

- (NSDictionary *)messagesToModifyDictionaryForFolder:(MCOIMAPFolder *)folder {
	NSMutableArray *modifyArray = [[NSMutableArray alloc]init];
	NSMutableArray *deleteArray = [[NSMutableArray alloc]init];
	NSMutableArray *purgeArray = [[NSMutableArray alloc]init];
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:folder.path];
	FMResultSet *resultSet = [self.connection executeQuery:@"select rowid, flags, original_flags, deleted from message indexed by message_uid_index where folder_idx = ?", @(folderIdentifier)];
	if ([resultSet next]) {
		@autoreleasepool {
			while ([resultSet next]) {
				int flags = [resultSet intForColumn:@"flags"];
				int originalFlags = [resultSet intForColumn:@"original_flags"];
				long long rowID = [resultSet longLongIntForColumn:@"rowid"];
				int deleted = [resultSet intForColumn:@"deleted"];
				if ((flags == originalFlags) && originalFlags != 0) {
					continue;
				}
				MCOIMAPMessage *message = (MCOIMAPMessage *)[self lookupCachedMessageAtRowIndex:rowID];
				[message setOriginalFlags:originalFlags];
				[message setFlags:flags];
				[message dm_setFolder:folder];
				if (message != nil) {
					[modifyArray addObject:message];
					if (deleted == 2) {
						[purgeArray addObject:message];
						continue;
					}
					if (deleted != 1) {
						continue;
					}
					[deleteArray addObject:message];
				}
			}
		}
	}
	NSMutableDictionary *result = [[NSMutableDictionary alloc]init];
	[result setObject:modifyArray forKey:@"Modify"];
	[result setObject:deleteArray forKey:@"Delete"];
	[result setObject:purgeArray forKey:@"Purge"];
	return result;
}


- (NSArray *)diffCachedMessageFlagsForPath:(NSString *)path withMessage:(NSArray *)messages {
	NSString *flagsPath = [[[self.path stringByAppendingPathComponent:@"Cache"]stringByAppendingPathComponent:[path dmEncodedURLValue]]stringByAppendingPathComponent:@"flags.dmarchive"];
	NSDictionary *flagsDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithContentsOfFile:flagsPath]];
	NSMutableArray *diff = [[NSMutableArray alloc]init];
	for (MCOIMAPMessage *message in messages) {
		NSNumber *flags = [flagsDictionary objectForKey:[NSString stringWithFormat:@"%u", message.uid]];
		if (flags != nil) {
			if ([flags intValue] == message.flags) {
				continue;
			}
		}
		[diff addObject:@(message.uid)];
	}
	return diff;
}

- (void)markMessageAsDeleted:(PSTSerializableMessage *)message {
	NSUInteger messageIndex = [self indexOfMessage:message atPath:message.dm_folder.path];
	[self.connection executeUpdate:@"update message set deleted = 1 where rowid = ?", @(messageIndex)];
	[self _updateConversationVisibilityWithMessage:messageIndex];
}


- (void)removeLocalMessagesForFolderPath:(NSString *)path  {
	NSMutableArray *array = [[NSMutableArray alloc]init];
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
	FMResultSet *resultsSet = [self.connection executeQuery:@"select rowid from message indexed by message_uid_index where folder_idx = ? and deleted = 0 and is_deleted = 0 and is_local = 1", @(folderIdentifier)];
	if ([resultsSet next]) {
		while ([resultsSet next]) {
			[array addObject:@([resultsSet longLongIntForColumn:@"rowid"])];
		}
	}
	[resultsSet close];
	for (NSNumber *rowID in array) {
		[self _removeMessageWithRowID:[rowID longLongValue]];
	}
}

#pragma mark - Flags

- (void)_setMessageFlags:(MCOMessageFlag)messageFlags forUID:(uint32_t)uid path:(NSString *)path {
	@autoreleasepool {
		NSMutableDictionary *flagsDict = [[NSMutableDictionary alloc]init];
		[flagsDict setObject:[NSNumber numberWithInt:messageFlags] forKey:@"flags"];
		[self.flagsCache setData:[NSKeyedArchiver archivedDataWithRootObject:flagsDict] forKey:[NSString stringWithFormat:@"%@-%u", [path dmEncodedURLValue], uid]];
	}
}

- (void)cacheOriginalFlagsFromMessage:(MCOAbstractMessage *)message inFolder:(NSString *)folder{
	if (![message isKindOfClass:[MCOIMAPMessage class]]) {
		return;
	}
	MCOIMAPMessage *castMsg = (MCOIMAPMessage *)message;
	[self _setMessageFlags:[castMsg originalFlags] forUID:castMsg.uid path:folder];
}

- (void)cacheFlagsFromMessage:(MCOAbstractMessage *)message inFolder:(NSString *)path {
	if (![message isKindOfClass:[MCOIMAPMessage class]]) {
		return;
	} else {
		MCOIMAPMessage *castMsg = (MCOIMAPMessage *)message;
		[self _setMessageFlags:[castMsg flags] forUID:castMsg.uid path:path];
	}
}

- (void)appendCachedMessageFlags:(NSMutableDictionary *)flagsDict forPath:(NSString *)path {
	NSData *archiveData = [NSData dataWithContentsOfFile:[[[self.path stringByAppendingPathComponent:@"Cache"]stringByAppendingPathComponent:[path dmEncodedURLValue]]stringByAppendingPathComponent:@"flags.dmarchive"]];
	NSMutableDictionary *flagsArchiveDict = [[NSKeyedUnarchiver unarchiveObjectWithData:archiveData]mutableCopy];
	if (flagsArchiveDict == nil) {
		flagsArchiveDict = [[NSMutableDictionary alloc]init];
	}
	NSMutableDictionary *dict = [[NSMutableDictionary alloc]initWithCapacity:flagsDict.count];
	[flagsArchiveDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if ([flagsDict objectForKey:key] != nil) {
			return;
		} else {
			[dict setObject:obj forKey:key];
		}
	}];
	[flagsArchiveDict addEntriesFromDictionary:dict];
	[self saveCachedMessageFlags:flagsArchiveDict forPath:path];
}

- (void)saveCachedMessageFlags:(NSDictionary *)flags forPath:(NSString *)path {
	NSString *flagsPath = [[[self.path stringByAppendingPathComponent:@"Cache"]stringByAppendingPathComponent:[path dmEncodedURLValue]]stringByAppendingPathComponent:@"flags.dmarchive"];
	[[NSKeyedArchiver archivedDataWithRootObject:flags]writeToFile:flagsPath atomically:YES];
	
}

- (BOOL)areFlagsChangedOnMessage:(MCOAbstractMessage *)message forPath:(NSString *)folderPath {
	BOOL result = NO;
	if ([message isKindOfClass:[MCOIMAPMessage class]]) {
		NSData *flagsData = [self.flagsCache dataForKey:[NSString stringWithFormat:@"%@-%u", folderPath.dmEncodedURLValue, ((MCOIMAPMessage *)message).uid]];
		if (flagsData != nil) {
			NSDictionary *flagsDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:flagsData];
			if (flagsDictionary == nil) {
				return YES;
			}
			NSNumber *flags = [flagsDictionary objectForKey:@"flags"];
			if (flags != nil) {
				result = [flags intValue] != ((MCOIMAPMessage *)message).flags;
			} else {
				return YES;
			}
		}
	}
	return result;
}

- (BOOL)updateMessageFlagsFromServer:(MCOAbstractMessage *)message forFolder:(NSString *)folderPath {
	BOOL result = NO;
	if (folderPath != nil) {
		NSUInteger folderIdentifier = [self _folderIdentifierForPath:folderPath];
		FMResultSet *resultSet = [self.connection executeQuery:@"select rowid, flags, original_flags, conversation_id from message where uid = ? and folder_idx = ?", @(((MCOIMAPMessage *)message).uid),@(folderIdentifier)];
		if (![resultSet next]) {
			result = NO;
			[resultSet close];
		} else {
			NSUInteger rowID = [resultSet longLongIntForColumn:@"rowid"];
			MCOMessageFlag flags = [resultSet intForColumn:@"flags"];
			NSUInteger originalFlags = [resultSet longLongIntForColumn:@"original_flags"];
			NSUInteger conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
			[resultSet close];
			MCOMessageFlag serverMessageFlags = [(MCOIMAPMessage *)message flags];
			result = NO;
			if (originalFlags != [(MCOIMAPMessage *)message flags]) {
				BOOL isSeen = serverMessageFlags & MCOMessageFlagSeen;
				BOOL isFlagged = serverMessageFlags & MCOMessageFlagFlagged;
				BOOL isDeleted = serverMessageFlags & MCOMessageFlagDeleted;
				[self.connection executeUpdate:@"update message set flags = ?, original_flags = ?, is_read = ?, is_flagged = ?, is_deleted = ? where uid = ? and folder_idx = ?", @(flags), @(serverMessageFlags), @(isSeen), @(isFlagged), @(isDeleted), @(((MCOIMAPMessage *)message).uid),@(folderIdentifier)];
				PUISSANT_FMDB_ERROR_LOG
				[self _updateMessageFlagsAtRowID:rowID flags:serverMessageFlags originalFlags:flags];
				[self _resetDiffingState];
				[self.invalidConversationRowIDs addIndex:conversationID];
				[self _updateConversationVisibility:conversationID folderID:folderIdentifier];
				result = YES;
			}
			
		}
	}
	return result;
}

- (void)updateMessageFlagsFromUser:(MCOAbstractMessage *)message forFolder:(NSString *)folderPath {
	NSUInteger rowID = [self indexOfMessage:message atPath:folderPath];
	if (rowID != NSUIntegerMax) {
		MCOMessageFlag flags = [(MCOIMAPMessage *)message flags];
		BOOL isSeen = flags & MCOMessageFlagSeen;
		BOOL isFlagged = flags & MCOMessageFlagFlagged;
		BOOL isDeleted = flags & MCOMessageFlagDeleted;
		[self.connection executeUpdate:@"update message set flags = ?, flags_dirty = 1, is_read = ?, is_flagged = ?, is_deleted = ? where rowid = ?", @(flags), @(isSeen), @(isFlagged), @(isDeleted),@(rowID)];
		PUISSANT_FMDB_ERROR_LOG
		[self _updateMessageRowID:rowID flags:flags];
		[self _updateConversationVisibilityWithMessage:rowID];
		if (![message isKindOfClass:[MCOIMAPMessage class]]) {
			return;
		} else {
			[self cacheOriginalFlagsFromMessage:message inFolder:folderPath];
		}
	}
}

#pragma mark - Incomplete Message Data

- (NSUInteger)firstIncompleteUIDToFetch:(NSString *)path givenLastUID:(NSUInteger)lastUID {
	NSUInteger result = 0;
	NSIndexSet *incompletes = [self _incompleteMessagesUIDsIndexSetForPath:path];
	if (lastUID != 0) {
		result = [incompletes indexLessThanIndex:lastUID];
	} else {
		result = [incompletes lastIndex];
	}
	if (result != NSUIntegerMax) {
		result = NSUIntegerMax;
	}
	return 0;
}

- (NSUInteger)countOfIncompleteMessagesForFolderPath:(NSString *)path {
	return [self _incompleteMessagesUIDsIndexSetForPath:path].count;
}

- (NSIndexSet *)incompleteMessagesSetForFolderPath:(NSString *)path lastUID:(NSUInteger)lastUID limit:(NSUInteger)limit {
	NSMutableIndexSet *result = [[NSMutableIndexSet alloc]init];
	NSIndexSet *incompletes = [self _incompleteMessagesUIDsIndexSetForPath:path];
	__block int limitBreak = 0;
	[incompletes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
		if (limitBreak >= limit) {
			*stop = YES;
		} else if (lastUID <= idx){
			[result addIndex:idx];
			limitBreak++;
		}
	}];
	return result;
}

#pragma mark - Message Previews

- (NSString *)previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	NSData *lookupData = nil;
	NSString *result = nil;
	if ([message isKindOfClass:MCOIMAPMessage.class]) {
		if (((MCOIMAPMessage *)message).attachments == nil) {
			lookupData = [self.previewCache dataForKey:PSTIdentifierForMessage(message, path)];
			result = [NSString stringWithUTF8String:(const char *)lookupData.bytes];
		}
		else if ([((MCOIMAPMessage *)message) htmlInlineAttachments].count != 0) {
			lookupData = [self.previewCache dataForKey:PSTIdentifierForMessage(message, path)];
			result = [NSString stringWithUTF8String:(const char *)lookupData.bytes];
		}
	} else {
		if (((PSTSerializableMessage *)message).attachments == nil) {
			lookupData = [self.previewCache dataForKey:PSTIdentifierForMessage(message, path)];
			result = [NSString stringWithUTF8String:(const char *)lookupData.bytes];
		}
	}
	return result;
}

- (BOOL)hasPreviewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	BOOL result = YES;
	if ([message isKindOfClass:MCOIMAPMessage.class]) {
		if (((MCOIMAPMessage *)message).attachments == nil) {
			result = [self.previewCache hasDataForKey:PSTIdentifierForMessage(message, path)];
		}
		else if ([((MCOIMAPMessage *)message) htmlInlineAttachments].count != 0) {
			result = [self.previewCache hasDataForKey:PSTIdentifierForMessage(message, path)];
		}
	} else {
		if (((PSTSerializableMessage *)message).attachments == nil) {
			result = [self.previewCache hasDataForKey:PSTIdentifierForMessage(message, path)];
		}
	}
	return result;
}

- (NSString *)previewForConversationCache:(PSTConversationCache *)cache {
	NSData *previewData = [self.previewCache dataForKey:PSTIdentifierForConversationCachePreview(cache)];
	if (previewData != nil) {
		return [NSString stringWithUTF8String:(void *)previewData.bytes];
	}
	return nil;
}

- (BOOL)hasPreviewForConversationCache:(PSTConversationCache *)cache {
	return [self.previewCache hasDataForKey:PSTIdentifierForConversationCachePreview(cache)];
}

- (void)addPreviewObserverForUID:(NSString *)key withBlock:(void(^)(NSData *))block {
	[self.previewCache addObserverForUID:key withBlock:block];
}

- (void)removePreviewObserverForUID:(NSString *)uid {
	[self.previewCache removeObserverForUID:uid];
}

#pragma mark - Counting Operations

- (NSUInteger)countForPath:(NSString *)path {
	NSUInteger result = 0;
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
	FMResultSet *resultSet = [self.connection executeQuery:@"select count(distinct conversation_id) from message where folder_idx = ? and deleted = 0 and is_deleted = 0", @(folderIdentifier)];
	if ([resultSet next]) {
		result = [resultSet intForColumnIndex:0];
	}
	[resultSet close];
	return result;
}

- (void)setCount:(NSUInteger)count forPath:(NSString *)path {
	if ([NSThread currentThread] == [NSThread mainThread]) {
		//do nothing
	} else {
		NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
		[self.connection executeUpdate:@"update mailbox set count = ? where rowid = ?", @(count), @(folderIdentifier)];
		if ([self.connection hadError]) {
			PSTLog(@"PSTMessageDatabase error %d: %@", self.connection.lastErrorCode, self.connection.lastErrorMessage);
		}
	}
	[self.folderCounts setObject:@(count) forKey:path];
}

- (NSUInteger)unseenCountForPath:(NSString *)path {
	NSUInteger result = 0;
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
	FMResultSet *resultSet = [self.connection executeQuery:@"select count(distinct conversation_id) from message indexed by message_read_idx where folder_idx = ? and is_read = 0 and deleted = 0 and is_deleted = 0", @(folderIdentifier)];
	if ([resultSet next]) {
		result = [resultSet intForColumnIndex:0];
	}
	[resultSet close];
	return result;
}

- (void)setUnseenCount:(NSUInteger)count forPath:(NSString *)path {
	if ([NSThread currentThread] == [NSThread mainThread]) {
		//do nothing
	} else {
		NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
		[self.connection executeUpdate:@"update mailbox set unseen_count = ? where rowid = ?", @(count), @(folderIdentifier)];
		if ([self.connection hadError]) {
			PSTLog(@"PSTMessageDatabase error %d: %@", self.connection.lastErrorCode, self.connection.lastErrorMessage);
		}
	}
	[self.folderUnreadCounts setObject:@(count) forKey:path];
}

- (NSUInteger)countForStarredNotInTrashFolderPath:(NSString *)path; {
	NSUInteger result = 0;
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
	FMResultSet *resultSet = [self.connection executeQuery:@"select count(distinct conversation_id) from message where is_flagged = 1 and folder_idx != ? and deleted = 0 and is_deleted = 0", @(folderIdentifier)];
	if ([resultSet next]) {
		result = [resultSet intForColumnIndex:0];
	}
	[resultSet close];
	return result;
}

- (NSUInteger)countForNextStepsNotInTrashFolderPath:(NSString *)path; {
	NSUInteger result = 0;
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
	FMResultSet *resultSet = [self.connection executeQuery:@"select count(distinct conversation_id) from conversation_data where action_step != 0 and folder_idx != ? and visible = 1", @(folderIdentifier)];
	if ([resultSet next]) {
		result = [resultSet intForColumnIndex:0];
	}
	[resultSet close];
	return result;
}

- (void)setCountForStarred:(NSUInteger)count {
	self.starredCount = count;
}

- (void)setCountForNextSteps:(NSUInteger)count {
	self.nextStepCount = count;
}

- (void)invalidateCountForPath:(NSString *)path {
	@synchronized(self) {
		[self.folderCounts removeObjectForKey:path];
	}
}

- (void)invalidateUnseenCountForPath:(NSString *)path {
	@synchronized(self) {
		[self.folderUnreadCounts removeObjectForKey:path];
	}
}

- (void)setCachedUnseenCount:(NSUInteger)count forPath:(NSString *)path {
	@synchronized(self) {
		[self.folderUnreadCounts setObject:[NSNumber numberWithUnsignedInteger:count] forKey:path];
	}
}

- (void)setCachedCount:(NSUInteger)count forPath:(NSString *)path {
	@synchronized(self) {
		[self.folderCounts setObject:@(count) forKey:path];
	}
}

- (void)invalidateCountForStarred {
	self.starredCount = NSUIntegerMax;
}

- (void)setCachedCountForStarred:(NSUInteger)count {
	self.starredCount = count;
}

- (void)invalidateCountForNextSteps {
	self.nextStepCount = NSUIntegerMax;
}

- (void)setCachedCountForNextSteps:(NSUInteger)count {
	self.nextStepCount = count;
}

- (NSUInteger)cachedCountForPath:(NSString *)path {
	NSUInteger result = 0;
	@synchronized(self) {
		NSNumber *cachedFolderCount = [self.folderCounts objectForKey:path];
		if (cachedFolderCount != nil) {
			result = [cachedFolderCount longLongValue];
		}
	}
	if (result == NSUIntegerMax) {
		result = 0;
		if ([NSThread currentThread] != [NSThread mainThread]) {
			NSUInteger folderIdentifier = [self _folderIdentifierForPath:path];
			FMResultSet *resultSet = [self.connection executeQuery:@"select count from mailbox where rowid = ?", @(folderIdentifier)];
			if ([resultSet next]) {
				result = [resultSet intForColumn:@"count"];
				[resultSet close];
				@synchronized(self) {
					[self.folderCounts setObject:@(result) forKey:path];
				}
			}
			[resultSet close];
		}
	}
	return result;
}

- (NSUInteger)cachedUnseenCountForPath:(NSString *)path {
	NSUInteger retVal = 0;
	@synchronized (self) {
		NSNumber *unreadCount = [self.folderUnreadCounts objectForKey:path];
		if (unreadCount != nil) {
			retVal = [unreadCount longLongValue];
			if (retVal == LLONG_MAX) {
				if ([NSThread currentThread] != [NSThread mainThread]) {
					NSNumber *folderIdentifier = [NSNumber numberWithLongLong:[self _folderIdentifierForPath:path]];
					FMResultSet *resultsSet = [self.connection executeQuery:@"select unseen_count from mailbox where rowid = ?", folderIdentifier];
					if ([resultsSet next]) {
						retVal = [resultsSet intForColumn:@"unseen_count"];
						@synchronized (self) {
							[self.folderUnreadCounts setObject:[NSNumber numberWithLongLong:retVal] forKey:path];
						}
					}
					[resultsSet close];
				}
			}
			return retVal;
		}
	}
	if ([NSThread currentThread] != [NSThread mainThread]) {
		NSNumber *folderIdentifier = [NSNumber numberWithLongLong:[self _folderIdentifierForPath:path]];
		FMResultSet *resultsSet = [self.connection executeQuery:@"select unseen_count from mailbox where rowid = ?", folderIdentifier];
		if ([resultsSet next]) {
			retVal = [resultsSet intForColumn:@"unseen_count"];
			@synchronized (self) {
				[self.folderUnreadCounts setObject:[NSNumber numberWithLongLong:retVal] forKey:path];
			}
		}
		[resultsSet close];
	}
	return retVal;
}

- (NSUInteger)cachedCountForStarredNotInTrashFolderPath:(NSString *)trashFolderPath {
	NSUInteger result = 0;
	if (self.starredCount == NSUIntegerMax) {
		result = 0;
		if ([NSThread currentThread] != [NSThread mainThread]) {
			self.starredCount = [self countForStarredNotInTrashFolderPath:trashFolderPath];
			result = self.starredCount;
		}
	}
	return result;
}

- (NSUInteger)cachedCountForNextStepsNotInTrashFolderPath:(NSString *)trashFolderPath {
	NSUInteger result = self.nextStepCount;
	if (self.nextStepCount == NSUIntegerMax) {
		result = 0;
		if ([NSThread currentThread] != [NSThread mainThread]) {
			self.nextStepCount = [self countForNextStepsNotInTrashFolderPath:trashFolderPath];
			result = self.nextStepCount;
		}
	}
	return result;
}

#pragma mark - Conversation Fetch

#pragma mark - Conversations

- (NSMutableArray *)conversationsForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder limit:(NSUInteger)limit {
	return [self conversationsForFolder:folder otherFolder:otherFolder allMailFolder:NO limit:limit];
}

- (NSMutableArray *)conversationsForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder allMailFolder:(BOOL)allMailFolder limit:(NSUInteger)limit {
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = YES;
	}
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:folder.path];
	NSUInteger otherFolderIdentifier = NSUIntegerMax;
	if (allMailFolder) {
		otherFolderIdentifier = [self _folderIdentifierForPath:otherFolder.path];
	}
	FMResultSet *resultSet = nil;
	if (otherFolderIdentifier == NSUIntegerMax) {
		if (limit != 0) {
			resultSet = [self.connection executeQuery:@"select action_step,folder_idx,conversation_id,most_recent_message_date from conversation_data where folder_idx = ? and is_facebook = 0 and is_twitter = 0 and visible = 1 limit ?", @(folderIdentifier), @(limit)];
		} else {
			resultSet = [self.connection executeQuery:@"select action_step,folder_idx,conversation_id,most_recent_message_date from conversation_data where folder_idx = ? and is_facebook = 0 and is_twitter = 0 and visible = 1", @(folderIdentifier)];
		}
	} else {
		if (limit != 0) {
			resultSet = [self.connection executeQuery:@"select action_step,folder_idx,conversation_id,most_recent_message_date from conversation_data where folder_idx in (?, ?) and is_facebook = 0 and is_twitter = 0 and visible = 1 limit ?", @(folderIdentifier), @(otherFolderIdentifier), @(limit)];
		} else {
			resultSet = [self.connection executeQuery:@"select action_step,folder_idx,conversation_id,most_recent_message_date from conversation_data where folder_idx in (?, ?) and is_facebook = 0 and is_twitter = 0 and visible = 1", @(folderIdentifier), @(otherFolderIdentifier)];
		}
	}
	PUISSANT_FMDB_ERROR_LOG
	NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
	BOOL cancelled;
	@autoreleasepool {
		while ([resultSet next] && cancelled == NO) {
			long long conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
			PSTActionStepValue actionStep = [resultSet intForColumn:@"action_step"];
			NSDate *lastRecievedMessageDate = [resultSet dateForColumn:@"most_recent_message_date"];
			if (lastRecievedMessageDate == nil) {
				lastRecievedMessageDate = [NSDate date];
			}
			PSTConversation *convo = [dict objectForKey:@(conversationID)];
			if (convo != nil) {
				if ([convo.sortDate compare:lastRecievedMessageDate] == NSOrderedDescending) {
					[convo setSortDate:lastRecievedMessageDate];
				}
			} else {
				PSTConversation *newConvo = [[PSTConversation alloc]init];
				[newConvo setSortDate:lastRecievedMessageDate];
				[newConvo setConversationID:conversationID];
				[newConvo setFolder:folder];
				[newConvo setOtherFolder:otherFolder];
				[newConvo setActionStep:actionStep];
				[dict setObject:newConvo forKey:@(conversationID)];
			}
			@synchronized(self) {
				cancelled = _databaseFlags.cancelConversations;
			}
			if (cancelled == NO) {
				continue;
			}
		}
		[resultSet close];
	}
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = NO;
	}
	return [[dict allValues]sortedArrayUsingSelector:@selector(compare:)].mutableCopy;
}

- (NSMutableArray *)starredConversationsNotInTrashFolder:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit {
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = YES;
	}
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:trashFolder.path];
	NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
	FMResultSet *resultSet = nil;
	if (limit != 0) {
		resultSet = [self.connection executeQuery:@"select conversation_id,date from message where is_flagged = 1 and folder_idx != ? and deleted = 0 and is_deleted = 0 limit ?", @(folderIdentifier), @(limit)];
	} else {
		resultSet = [self.connection executeQuery:@"select conversation_id,date from message where is_flagged = 1 and folder_idx != ? and deleted = 0 and is_deleted = 0", @(folderIdentifier)];
	}
	if ([self.connection hadError]) {
		PSTLog(@"PSTMessageDatabase error %d: %@", self.connection.lastErrorCode, self.connection.lastErrorMessage);
	}
	@autoreleasepool {
		BOOL cancelled;
		while ([resultSet next] && cancelled == NO) {
			long long conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
			NSDate *lastRecievedMessageDate = [resultSet dateForColumn:@"date"];
			if (lastRecievedMessageDate == nil) {
				lastRecievedMessageDate = [NSDate date];
			}
			PSTConversation *convo = [dict objectForKey:@(conversationID)];
			if (convo != nil) {
				if ([convo.sortDate compare:lastRecievedMessageDate] == NSOrderedDescending) {
					[convo setSortDate:lastRecievedMessageDate];
				}
			} else {
				PSTConversation *newConvo = [[PSTConversation alloc]init];
				[newConvo setSortDate:lastRecievedMessageDate];
				[newConvo setConversationID:@(conversationID)];
				[dict setObject:newConvo forKey:@(conversationID)];
			}
			@synchronized(self) {
				cancelled = _databaseFlags.cancelConversations;
			}
			if (cancelled == NO) {
				continue;
			}
		}
		[resultSet close];
	}
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = NO;
	}
	return [[dict allValues]sortedArrayUsingSelector:@selector(compare:)].mutableCopy;
}

- (NSMutableArray *)nextStepsConversationsOperationNotInTrashFolder:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit {
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = YES;
	}
	NSUInteger trashFolderIdentifier = [self _folderIdentifierForPath:trashFolder.path];
	FMResultSet *resultSet = nil;
	if (limit != 0) {
		resultSet = [self.connection executeQuery:@"select action_step,folder_idx,conversation_id,most_recent_message_date from conversation_data where folder_idx != ? and action_step != 0 and is_facebook = 0 and is_twitter = 0 and visible = 1 limit ?", @(trashFolderIdentifier), @(limit)];
	} else {
		resultSet = [self.connection executeQuery:@"select action_step,folder_idx,conversation_id,most_recent_message_date from conversation_data where folder_idx != ? and action_step != 0 and is_facebook = 0 and is_twitter = 0 and visible = 1", @(trashFolderIdentifier)];
	}
	if ([self.connection hadError]) {
		PSTLog(@"PSTMessageDatabase error %d: %@", self.connection.lastErrorCode, self.connection.lastErrorMessage);
	}
	NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
	BOOL cancelled = NO;
	@autoreleasepool {
		while ([resultSet next] && cancelled == NO) {
			long long conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
			PSTActionStepValue actionStep = [resultSet intForColumn:@"action_step"];
			NSDate *lastRecievedMessageDate = [resultSet dateForColumn:@"most_recent_message_date"];
			if (lastRecievedMessageDate == nil) {
				lastRecievedMessageDate = [NSDate date];
			}
			PSTConversation *convo = [dict objectForKey:@(conversationID)];
			if (convo != nil) {
				if ([convo.sortDate compare:lastRecievedMessageDate] == NSOrderedDescending) {
					[convo setSortDate:lastRecievedMessageDate];
				}
			} else {
				PSTConversation *newConvo = [[PSTConversation alloc]init];
				[newConvo setSortDate:lastRecievedMessageDate];
				[newConvo setConversationID:conversationID];
				[newConvo setActionStep:actionStep];
				[dict setObject:newConvo forKey:@(conversationID)];
			}
			@synchronized(self) {
				cancelled = _databaseFlags.cancelConversations;
			}
			if (cancelled == NO) {
				continue;
			}
		}
		[resultSet close];
	}
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = NO;
	}
	return [[dict allValues]sortedArrayUsingSelector:@selector(compare:)].mutableCopy;
}

- (NSMutableArray *)conversationsNotInTrashFolder:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit {
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = YES;
	}
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:trashFolder.path];
	FMResultSet *resultSet = nil;
	if (limit != 0) {
		resultSet = [self.connection executeQuery:@"select folder_idx,conversation_id,most_recent_message_date from message where folder_idx != ? and visible = 1 limit ?", @(folderIdentifier), @(limit)];
	} else {
		resultSet = [self.connection executeQuery:@"select folder_idx,conversation_id,most_recent_message_date from conversation_data where folder_idx != ? and visible = 1", @(folderIdentifier)];
	}
	PUISSANT_FMDB_ERROR_LOG
	NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
	BOOL cancelled = NO;
	@autoreleasepool {
		while ([resultSet next] && cancelled == NO) {
			long long conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
			NSDate *lastRecievedMessageDate = [resultSet dateForColumn:@"most_recent_message_date"];
			if (lastRecievedMessageDate == nil) {
				lastRecievedMessageDate = [NSDate date];
			}
			PSTConversation *convo = [dict objectForKey:@(conversationID)];
			if (convo != nil) {
				if ([convo.sortDate compare:lastRecievedMessageDate] == NSOrderedDescending) {
					[convo setSortDate:lastRecievedMessageDate];
				}
			} else {
				PSTConversation *newConvo = [[PSTConversation alloc]init];
				[newConvo setSortDate:lastRecievedMessageDate];
				[newConvo setConversationID:conversationID];
				[dict setObject:newConvo forKey:@(conversationID)];
			}
			@synchronized(self) {
				cancelled = _databaseFlags.cancelConversations;
			}
			if (cancelled == NO) {
				continue;
			}
			
		}
		[resultSet close];
	}
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = NO;
	}
	return [[dict allValues]sortedArrayUsingSelector:@selector(compare:)].mutableCopy;
}

- (NSMutableArray *)facebookNotificationsNotInTrash:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit {
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = YES;
	}
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:@"INBOX"];
	NSMutableArray *conversations = [[NSMutableArray alloc]init];
	FMResultSet *resultSet = nil;
	if (limit != 0) {
		resultSet = [self.connection executeQuery:@"select conversation_id from message where folder_idx = ? and is_facebook = 1 = 1 limit ?", @(folderIdentifier), @(limit)];
	} else {
		resultSet = [self.connection executeQuery:@"select conversation_id from message where folder_idx = ? and is_facebook = 1", @(folderIdentifier)];
	}
	if ([self.connection hadError]) {
		PSTLog(@"PSTMessageDatabase error %d: %@", self.connection.lastErrorCode, self.connection.lastErrorMessage);
	}
	@autoreleasepool {
		BOOL cancelled;
		while ([resultSet next] && cancelled == NO) {
			long long conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
			PSTConversation *newConvo = [[PSTConversation alloc]init];
			[newConvo setConversationID:conversationID];
			[conversations addObject:newConvo];
			@synchronized(self) {
				cancelled = _databaseFlags.cancelConversations;
			}
			if (cancelled == NO) {
				continue;
			}
		}
		[resultSet close];
	}
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = NO;
	}
	return conversations;
}

- (NSMutableArray *)twitterNotificationsNotInTrash:(MCOIMAPFolder *)trashFolder limit:(NSUInteger)limit {
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = YES;
	}
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:@"INBOX"];
	NSMutableArray *conversations = [[NSMutableArray alloc]init];
	FMResultSet *resultSet = nil;
	if (limit != 0) {
		resultSet = [self.connection executeQuery:@"select conversation_id from message where folder_idx = ? and is_twitter = 1 limit ?", @(folderIdentifier), @(limit)];
	} else {
		resultSet = [self.connection executeQuery:@"select conversation_id from message where folder_idx = ? and is_twitter = 1", @(folderIdentifier)];
	}
	PUISSANT_FMDB_ERROR_LOG
	@autoreleasepool {
		BOOL cancelled;
		while ([resultSet next] && cancelled == NO) {
			long long conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
			PSTConversation *newConvo = [[PSTConversation alloc]init];
			[newConvo setConversationID:conversationID];
			[conversations addObject:newConvo];
			@synchronized(self) {
				cancelled = _databaseFlags.cancelConversations;
			}
			if (cancelled == NO) {
				continue;
			}
		}
		[resultSet close];
	}
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = NO;
	}
	return conversations;
	
}

- (NSMutableArray *)unreadConversationsForFolder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder limit:(NSUInteger)limit {
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = YES;
	}
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:folder.path];
	NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
	FMResultSet *resultSet = nil;
	if (limit != 0) {
		resultSet = [self.connection executeQuery:@"select conversation_id,date from message where folder_idx = ? and is_read = 0 and deleted = 0 and is_deleted = 0 limit ?", @(folderIdentifier), @(limit)];
	} else {
		resultSet = [self.connection executeQuery:@"select conversation_id,date from message where folder_idx = ? and is_read = 0 and deleted = 0 and is_deleted = 0", @(folderIdentifier)];
	}
	if ([self.connection hadError]) {
		PSTLog(@"PSTMessageDatabase error %d: %@", self.connection.lastErrorCode, self.connection.lastErrorMessage);
	}
	@autoreleasepool {
		BOOL cancelled;
		while ([resultSet next] && cancelled == NO) {
			long long conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
			NSDate *lastRecievedMessageDate = [resultSet dateForColumn:@"date"];
			if (lastRecievedMessageDate == nil) {
				lastRecievedMessageDate = [NSDate date];
			}
			PSTConversation *convo = [dict objectForKey:@(conversationID)];
			if (convo != nil) {
				if ([convo.sortDate compare:lastRecievedMessageDate] == NSOrderedDescending) {
					[convo setSortDate:lastRecievedMessageDate];
				}
			} else {
				PSTConversation *newConvo = [[PSTConversation alloc]init];
				[newConvo setSortDate:lastRecievedMessageDate];
				[newConvo setFolder:folder];
				[newConvo setOtherFolder:otherFolder];
				[newConvo setConversationID:@(conversationID)];
				[dict setObject:newConvo forKey:@(conversationID)];
			}
			@synchronized(self) {
				cancelled = _databaseFlags.cancelConversations;
			}
			if (cancelled == NO) {
				continue;
			}
		}
		[resultSet close];
	}
	@synchronized(self) {
		_databaseFlags.cancelConversations = NO;
		_databaseFlags.conversationsStarted = NO;
	}
	return [[dict allValues]sortedArrayUsingSelector:@selector(compare:)].mutableCopy;
}

#pragma mark - Conversation Details Fetch

- (PSTConversationCache *)rawConversationCacheForConversationID:(NSUInteger)convoID {
	PSTConversationCache *conversation = [[self.conversationsCache dataForIndex:convoID]dmUnarchivedData];
	[conversation resolveCachedSendersAndRecipients];
	return conversation;
}

- (void)updateActionstepsForConversationID:(NSUInteger)conversationID actionStep:(PSTActionStepValue)actionStep {
	[self.connection executeUpdate:@"update conversation_data set action_step = ? where conversation_id = ?", @(actionStep), @(conversationID)];
	PUISSANT_FMDB_ERROR_LOG
}

- (NSArray *)localDraftMessagesForFolder:(MCOIMAPFolder *)folder {
	NSMutableArray *array = [NSMutableArray array];
	NSMutableArray *array2 = [NSMutableArray array];
	FMResultSet *resultSet = [self.connection executeQuery:@"select rowid,flags from message where folder_idx = ? and deleted = 0 and is_deleted = 0 and is_local = 1", [NSNumber numberWithLongLong:[self _folderIdentifierForPath:folder.path]]];
	if ([resultSet next]) {
		while ([resultSet next] != 0) {
			id res = [self lookupCachedMessageAtRowIndex:[resultSet longLongIntForColumn:@"rowid"]];
			MCOMessageFlag flags = (MCOMessageFlag)[resultSet longLongIntForColumn:@"flags"];
			if (res == nil) {
				[array addObject:[NSNumber numberWithLongLong:[resultSet longLongIntForColumn:@"rowid"]]];
			}
			else {
				[res setFlags:flags];
				[res setFolder:folder.path];
				[array2 addObject:res];
			}
		}
	}
	[resultSet close];
	for (NSNumber *rowID in array) {
		[self _removeMessageWithRowID:[rowID longLongValue]];
	}
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	for (id object in array2) {
		id objForKey = [dictionary objectForKey:[object header].messageID];
		if (objForKey != nil) {
			continue;
		}
		[dictionary setObject:object forKey:[object header].messageID];
	}
	
	return [dictionary allValues];
}

- (NSArray *)messagesForConversationID:(NSUInteger)conversationID mainFolder:(MCOIMAPFolder *)folder folders:(NSDictionary *)foldersDictionary draftsFolderPath:(NSString *)draftsFolderPath sentMailFolderPath:(NSString *)sentMailFolderPath {
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:folder.path];
	NSMutableDictionary *uniqueMessages = [[NSMutableDictionary alloc]init];
	NSUInteger inboxFolderIdentifier = [self _folderIdentifierForPath:@"INBOX"];
	NSUInteger draftsFolderIdentifier = [self _folderIdentifierForPath:draftsFolderPath];
	NSUInteger sentMailFolderIdentifier = [self _folderIdentifierForPath:sentMailFolderPath];
	
	PSTConversationCache *cache = [self _conversationCacheForConversationID:conversationID folderID:folderIdentifier otherFolderID:NSUIntegerMax inboxFolderID:inboxFolderIdentifier draftsFolderID:draftsFolderIdentifier sentFolderID:sentMailFolderIdentifier];
	if (cache.messages.count == 0) {
		
	}
	for (PSTCachedMessage *message in cache.messages) {
		PSTSerializableMessage *messageToAdd = (PSTSerializableMessage *)[self lookupCachedMessageAtRowIndex:message.rowID];
		if (messageToAdd != nil) {
			NSUInteger messageFolderID = message.folderID;
			NSString *folderPath = [self _folderPathForIdentifier:messageFolderID];
			if (folderPath != nil) {
				MCOIMAPFolder *folder = [foldersDictionary objectForKey:folderPath];
				if (folder != nil) {
					[messageToAdd dm_setFolder:folder];
					if (message.folderID == folderIdentifier) {
						[uniqueMessages setObject:messageToAdd forKey:[messageToAdd uniqueMessageIdentifer]];
					} else {
						MCOIMAPMessage *duplicateMessage = [uniqueMessages objectForKey:[messageToAdd uniqueMessageIdentifer]];
						if (duplicateMessage == nil) {
							[uniqueMessages setObject:messageToAdd forKey:[messageToAdd uniqueMessageIdentifer]];
						}
					}
				}
			}
		}
	}
	return [[uniqueMessages allValues] sortedArrayUsingComparator:^NSComparisonResult(PSTSerializableMessage *obj1, PSTSerializableMessage *obj2) {
		return [obj1.internalDate compare:obj2.internalDate];
	}];
}

- (NSArray *)messagesForConversationID:(NSUInteger)conversationID folder:(MCOIMAPFolder *)folder otherFolder:(MCOIMAPFolder *)otherFolder draftsFolderPath:(NSString *)draftsFolderPath sentMailFolderPath:(NSString *)sentMailFolderPath {
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:folder.path];
	NSUInteger otherFolderIdentifier = NSUIntegerMax;
	if (conversationID != 0) {
		otherFolderIdentifier = [self _folderIdentifierForPath:otherFolder.path];
	}
	NSMutableArray *messages = [[NSMutableArray alloc]init];
	NSUInteger inboxFolderIdentifier = [self _folderIdentifierForPath:@"INBOX"];
	NSUInteger draftsFolderIdentifier = [self _folderIdentifierForPath:draftsFolderPath];
	NSUInteger sentMailFolderIdentifier = [self _folderIdentifierForPath:sentMailFolderPath];
	PSTConversationCache *cache = [self _conversationCacheForConversationID:conversationID folderID:folderIdentifier otherFolderID:otherFolderIdentifier inboxFolderID:inboxFolderIdentifier draftsFolderID:draftsFolderIdentifier sentFolderID:sentMailFolderIdentifier];
	for (PSTCachedMessage *message in cache.messages) {
		MCOIMAPMessage *messageToAdd = (MCOIMAPMessage *)[self lookupCachedMessageAtRowIndex:message.rowID];
		if (messageToAdd != nil) {
			NSUInteger messageFolderID = message.folderID;
			NSString *folderPath = [self _folderPathForIdentifier:messageFolderID];
			if (folderPath != nil) {
				if (messageFolderID != folderIdentifier) {
					if (messageFolderID != otherFolderIdentifier) {
						if (message.folder == nil) {
							[messageToAdd dm_setFolder:folder];
							[messages addObject:messageToAdd];
						}
						continue;
					}
				}
			}
		}
	}
	return [messages sortedArrayUsingComparator:^NSComparisonResult(MCOIMAPMessage *obj1, MCOIMAPMessage *obj2) {
		return [obj1.header.receivedDate compare:obj2.header.receivedDate];
	}];
}

#pragma mark - Attachment Operations

- (NSArray *)attachmentsInFolder:(MCOIMAPFolder *)folder {
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:folder.path];
	NSMutableArray *attachments = [[NSMutableArray alloc]init];
	FMResultSet *resultSet = [self.connection executeQuery:@"select rowid,message_id,filename,filepath from attachment where filepath != 0 and folder_idx = ?", @(folderIdentifier)];
	if ([self.connection hadError]) {
		PSTLog(@"PSTMessageDatabase error %d: %@", self.connection.lastErrorCode, self.connection.lastErrorMessage);
	}
	@autoreleasepool {
		while ([resultSet next]) {
			NSUInteger messageID = [resultSet longLongIntForColumn:@"message_id"];
			NSString *filename = [resultSet stringForColumn:@"filename"];
			NSString *filePath = [resultSet stringForColumn:@"filepath"];
			if ([filename hasSuffix:@".p7s"]) continue;
			
			PSTSerializableMessage *msg = [self lookupCachedMessageAtRowIndex:messageID];
			PSTAttachmentCache *newAttach = [[PSTAttachmentCache alloc]init];
			[newAttach setFilename:filename];
			MCOMessageHeader *attachHeader = [[MCOMessageHeader alloc]init];
			attachHeader.from = msg.from;
			attachHeader.date = msg.date;
			attachHeader.receivedDate = msg.internalDate;
			[newAttach setHeader:attachHeader];
			[newAttach setFilepath:filePath];
			[newAttach setRowID:[NSString stringWithFormat:@"%lld", [resultSet longLongIntForColumn:@"rowid"]]];
			[attachments addObject:newAttach];
		}
		[resultSet close];
	}
	return [attachments sortedArrayUsingComparator:^NSComparisonResult(PSTAttachmentCache *obj1, PSTAttachmentCache *obj2) {
		return [obj2.header.date compare:obj1.header.date];
	}];
}

- (NSArray *)attachmentsNotInTrashFolder:(MCOIMAPFolder *)trashFolder orAllMailFolder:(MCOIMAPFolder *)allMailFolder{
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:trashFolder.path];
	NSUInteger allMailFolderIdentifier = [self _folderIdentifierForPath:allMailFolder.path];
	NSMutableArray *attachments = [[NSMutableArray alloc]init];
	FMResultSet *resultSet = [self.connection executeQuery:@"select rowid,message_id,filename,filepath from attachment where filepath != 0 and folder_idx != ? and folder_idx != ?", @(folderIdentifier), @(allMailFolderIdentifier)];
	if ([self.connection hadError]) {
		PSTLog(@"PSTMessageDatabase error %d: %@", self.connection.lastErrorCode, self.connection.lastErrorMessage);
	}
	@autoreleasepool {
		while ([resultSet next]) {
			NSUInteger messageID = [resultSet longLongIntForColumn:@"message_id"];
			NSString *filename = [resultSet stringForColumn:@"filename"];
			NSString *filePath = [resultSet stringForColumn:@"filepath"];
			if ([filename hasSuffix:@".p7s"]) continue;
			
			PSTSerializableMessage *msg = [self lookupCachedMessageAtRowIndex:messageID];
			PSTAttachmentCache *newAttach = [[PSTAttachmentCache alloc]init];
			[newAttach setFilename:filename];
			[newAttach setFilepath:filePath];
			MCOMessageHeader *attachHeader = [[MCOMessageHeader alloc]init];
			attachHeader.from = msg.from;
			attachHeader.receivedDate = msg.internalDate;
			[newAttach setHeader:attachHeader];
			[newAttach setRowID:[NSString stringWithFormat:@"%lld", [resultSet longLongIntForColumn:@"rowid"]]];
			[attachments addObject:newAttach];
		}
		[resultSet close];
	}
	return [attachments sortedArrayUsingComparator:^NSComparisonResult(PSTAttachmentCache *obj1, PSTAttachmentCache *obj2) {
		return [obj2.header.date compare:obj1.header.date];
	}];
}

- (MCOIMAPMessagePart *)attachmentToFetchForFolder:(MCOIMAPFolder *)folder maxUID:(NSUInteger)maxUID fetchNonTextAttachents:(BOOL)fetchNonTextAttachments {
	NSUInteger folderIdentifier = [self _folderIdentifierForPath:folder.path];
	FMResultSet *resultSet = nil;
	if (maxUID != 0) {
		resultSet = [self.connection executeQuery:@"select rowid, message_id, part_id from attachment where folder_idx = ? and has_contents = 0 and is_text = 1 and uid < ? order by uid desc limit 1", @(folderIdentifier), @(maxUID)];
	} else {
		resultSet = [self.connection executeQuery:@"select rowid, message_id, part_id from attachment where folder_idx = ? and has_contents = 0 and is_text = 1 order by uid desc limit 1", @(folderIdentifier)];
	}
	PUISSANT_FMDB_ERROR_LOG
	if ([resultSet next]) {
		NSString *part_id = [resultSet stringForColumn:@"part_id"];
		NSUInteger messageID = [resultSet longLongIntForColumn:@"message_id"];
		//		NSUInteger rowID = [resultSet longLongIntForColumn:@"rowid"];
		[resultSet close];
		MCOAbstractMessage *message = [self lookupCachedMessageAtRowIndex:messageID];
		NSMutableDictionary *dictonary = [[NSMutableDictionary alloc]init];
		if (message == nil) {
			NSAssert(0, @"Invalid cache lookup not specifying message != nil");
			return nil;
		}
		[(MCOIMAPMessage *)message dm_setFolder:folder];
		[dictonary setObject:message forKey:@"Message"];
		if ([message isKindOfClass:[MCOIMAPMessage class]]) {
			for (MCOIMAPMessagePart *attachment in [message allAttachments]) {
				if ([attachment.partID isEqualToString:part_id]) {
					[dictonary setObject:attachment forKey:@"Attachment"];
					
				}
			}
		}
		return dictonary[@"Attachment"];
	}
	[resultSet close];
	return nil;
}


- (BOOL)hasDataForAttachmentMessage:(MCOAbstractMessage *)message atPath:(NSString *)path partID:(NSString *)part_id filename:(NSString *)filename mimeType:(NSString *)mimeType {
	BOOL result = YES;
	if (![self.plainTextCache hasDataForKey:PSTIdentifierForAttachmentWithPath(message, part_id, path)]) {
		result = NO;
		NSString *filePath = [self _filenameForAttachment:message atPath:path partID:part_id filename:filename mimeType:mimeType shouldCreate:NO];
		if (filePath != nil) {
			result = [NSFileManager.defaultManager fileExistsAtPath:filePath];
		}
	}
	return result;
}

- (NSData *)dataForAttachmentMessage:(MCOAbstractMessage *)message atPath:(NSString *)path partID:(NSString *)part_id filename:(NSString *)filename mimeType:(NSString *)mimeType {
	NSData *result = [self.plainTextCache dataForKey:PSTIdentifierForAttachmentWithPath(message, part_id, path)];
	if (result == nil) {
		result = [NSData dataWithContentsOfFile:[self _filenameForAttachment:message atPath:path partID:part_id filename:filename mimeType:mimeType]];
	}
	return result;
}

#pragma mark - Search

- (BOOL)matchSearchStrings:(NSArray *)searchStrings withString:(NSString *)string {
	if (string == 0) {
		return NO;
	}
	return [string dmMatchSearchStrings:searchStrings];
}

- (NSArray *)searchConversationsWithTerms:(NSArray *)searchTerms kind:(NSInteger)kind folder:(NSString *)folder
							  otherFolder:(NSString *)otherFolder mainFolders:(NSDictionary *)mainFolders
									 mode:(NSInteger)mode limit:(NSInteger)limit returningEverything:(BOOL)returningEverything {
	return @[];
}

#pragma mark - Private

- (void)_updateMessageRowID:(NSUInteger)rowID flags:(MCOMessageFlag)serverMessageFlags {
	PSTSerializableMessage *message = [self lookupCachedMessageAtRowIndex:rowID];
	[(PSTSerializableMessage *)message setFlags:serverMessageFlags];
	[self cacheMessage:message atRowIndex:rowID];
}

- (void)_updateMessageFlagsAtRowID:(NSUInteger)rowID flags:(MCOMessageFlag)serverMessageFlags originalFlags:(MCOMessageFlag)originalFlags {
	PSTSerializableMessage *message = [self lookupCachedMessageAtRowIndex:rowID];
	[(PSTSerializableMessage *)message setFlags:serverMessageFlags];
	[(PSTSerializableMessage *)message setOriginalFlags:originalFlags];
	[self cacheMessage:message atRowIndex:rowID];
}

- (NSString *)_filenameForAttachment:(MCOAbstractMessage *)message atPath:(NSString *)path partID:(NSString *)part_id filename:(NSString *)filename mimeType:(NSString *)mimeType {
	return [self _filenameForAttachment:message atPath:path partID:part_id filename:filename mimeType:mimeType shouldCreate:NO];
}

- (NSString *)_filenameForAttachment:(MCOAbstractMessage *)message  atPath:(NSString *)path partID:(NSString *)part_id filename:(NSString *)filename mimeType:(NSString *)mimeType shouldCreate:(BOOL)shouldCreate {
	NSString *attachmentPath = [[self _pathForMessage:message path:path]stringByAppendingPathComponent:filename];
	NSString *filenameForDataAttachment = [NSString dmAttachmentFilenameWithBasePath:attachmentPath filename:filename mimeType:mimeType defaultName:@"data" withExtension:@""];
	if ([[NSFileManager defaultManager]fileExistsAtPath:filenameForDataAttachment]) {
		return filenameForDataAttachment;
	}
	NSString *filenameForUntitledAttachment = [NSString dmAttachmentFilenameWithBasePath:attachmentPath filename:filename mimeType:mimeType defaultName:@"Untitled" withExtension:@""];
	if ([[NSFileManager defaultManager]fileExistsAtPath:filenameForUntitledAttachment]) {
		return filenameForUntitledAttachment;
	}
	
	NSString *filenameForAttachment = [NSString dmAttachmentFilenameWithBasePath:attachmentPath filename:filename mimeType:mimeType defaultName:nil withExtension:filename.pathExtension];
	if ([[NSFileManager defaultManager]fileExistsAtPath:filenameForAttachment]) {
		return filenameForAttachment;
	}
	if (message == nil) return nil;
	[self _writeAttachment:message atPath:path partID:part_id toFile:filenameForAttachment];
	return filenameForAttachment;
}

- (void)_writeAttachment:(MCOAbstractMessage *)message atPath:(NSString *)path partID:(NSString *)part_id toFile:(NSString *)toFile {
	if (![[NSFileManager defaultManager]fileExistsAtPath:toFile]) {
		NSData *attachmentData = [self.plainTextCache dataForKey:PSTIdentifierForAttachmentWithPath(message, part_id, path)];
		if (attachmentData != nil) {
			[[NSFileManager defaultManager]createDirectoryAtPath:[toFile stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
			[attachmentData writeToFile:toFile atomically:YES];
		}
	}
}

- (void)_loadMessagesUIDsForPath:(NSString *)path {
	if ([self.incompleteUIDsPathways objectForKey:path]) {
		return;
	}
	NSString *uidsPlistPath = [[[self.path stringByAppendingPathComponent:@"Cache"]stringByAppendingPathComponent:[path dmEncodedURLValue]]stringByAppendingPathComponent:@"uids.plist"];
	NSString *uidsPath = [[[self.path stringByAppendingPathComponent:@"Cache"]stringByAppendingPathComponent:[path dmEncodedURLValue]]stringByAppendingPathComponent:@"uids"];
	if (![[NSFileManager defaultManager]fileExistsAtPath:uidsPath]) {
		if (![[NSFileManager defaultManager]fileExistsAtPath:uidsPlistPath]) {
			[[NSFileManager defaultManager]createDirectoryAtPath:[uidsPlistPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
			[NSKeyedArchiver archiveRootObject:[NSDictionary dictionary] toFile:uidsPlistPath];
			[self.incompleteUIDsPathways setObject:[NSMutableIndexSet indexSet] forKey:path];
			[self _setLastUID:0 forPath:path];
			return;
		}
		NSDictionary *incompleteDict = [NSDictionary dictionaryWithContentsOfFile:uidsPlistPath];
		NSIndexSet *set = PSTIndexSetOfNumbers([incompleteDict objectForKey:@"incomplete"]);
		[self.incompleteUIDsPathways setObject:set forKey:path];
		long long lastUID = 0;
		if ([incompleteDict objectForKey:@"lastuid"]) {
			lastUID = [[incompleteDict objectForKey:@"lastuid"]longLongValue];
		}
		[self _setLastUID:lastUID forPath:path];
		[self _saveMessagesUIDsForPath:path];
		[[NSFileManager defaultManager]removeItemAtPath:uidsPlistPath error:nil];
	}
	NSDictionary *incompletesDictionary = [NSKeyedUnarchiver unarchiveObjectWithFile:uidsPath];
	if (incompletesDictionary == nil) {
		incompletesDictionary = [NSDictionary dictionary];
		[self.incompleteUIDsPathways setObject:[NSMutableIndexSet indexSet] forKey:path];
		[self _setLastUID:0 forPath:path];
		[NSKeyedArchiver archiveRootObject:incompletesDictionary toFile:uidsPath];
	}
	NSMutableIndexSet *incompletesSet = [[incompletesDictionary objectForKey:@"incomplete"]mutableCopy] ;
	if (incompletesSet == nil) {
		incompletesSet = [NSMutableIndexSet indexSet];
	}
	[self.incompleteUIDsPathways setObject:incompletesSet forKey:path];
	long long lastUID = 0;
	if ([incompletesDictionary objectForKey:@"lastuid"]) {
		lastUID = [[incompletesDictionary objectForKey:@"lastuid"]longLongValue];
	}
	[self _setLastUID:lastUID forPath:path];
}

- (void)_saveMessagesUIDsForPath:(NSString *)path {
	if (![self.uidsModified containsObject:path]) return;
	else {
		NSString *uidsPath = [[[self.path stringByAppendingPathComponent:@"Cache"]stringByAppendingPathComponent:[path dmEncodedURLValue]]stringByAppendingPathComponent:@"uids"];
		[[NSFileManager defaultManager]createDirectoryAtPath:[uidsPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
		NSMutableDictionary *incompleteDict = [NSMutableDictionary dictionary];
		NSMutableIndexSet *incompletesSet = [self _incompleteMessagesUIDsIndexSetForPath:path];
		if (incompletesSet == nil) {
			incompletesSet = [NSMutableIndexSet indexSet];
		}
		[incompleteDict setObject:incompletesSet forKey:@"incomplete"];
		[NSKeyedArchiver archiveRootObject:incompleteDict toFile:uidsPath];
	}
}

- (NSMutableIndexSet *)_incompleteMessagesUIDsIndexSetForPath:(NSString *)path {
	[self _loadMessagesUIDsForPath:path];
	return [self.incompleteUIDsPathways objectForKey:path];
}

- (void)removeMessageUID:(uint32_t)uid path:(NSString *)path {
	[NSFileManager.defaultManager removeItemAtPath:[self _pathForMessageUID:uid path:path] error:nil];
	[self _removeMessageWithRowID:[self _rowIDForMessageUID:uid folderPath:path]];
}

- (void)removeLocalDraftMessageID:(NSString *)msgID path:(NSString *)path beforeDate:(NSDate *)date {
	
}

- (void)_clearPreviewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	[self.previewCache removeDataForKey:PSTIdentifierForMessage(message, path)];
}

- (BOOL)generatePreviewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)folderPath {
	BOOL result = NO;
	if ([message isKindOfClass:[PSTLocalMessage class]]) {
		[self _generatePreviewForMessage:message atPath:folderPath];
		for (PSTLocalAttachment *attachment in ((PSTLocalMessage *)message).attachments) {
			[[NSFileManager defaultManager]createDirectoryAtPath:[self _filenameForAttachment:message atPath:folderPath partID:attachment.partID filename:attachment.filename mimeType:attachment.mimeType] withIntermediateDirectories:YES attributes:nil error:nil];
			[attachment.data writeToFile:[self _filenameForAttachment:message atPath:folderPath partID:attachment.partID filename:attachment.filename mimeType:attachment.mimeType] atomically:NO];
		}
		result = YES;
	} else {
		result = YES;
		if ([((MCOIMAPMessage *)message).mainPart allAttachments] != nil) {
			if ([message htmlInlineAttachments].count != 0) {
				[self _generatePreviewForMessage:message atPath:folderPath];
			} else {
				[self _clearPreviewForMessage:message atPath:folderPath];
			}
		}
		result = YES;
	}
	return result;
}

- (void)_generatePreviewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	NSUInteger rowID = [self indexOfMessage:message atPath:path];
	if (![message isKindOfClass:[MCOIMAPMessage class]]) {
		NSString *preview = [self _previewForMessage:message atPath:path messageRowID:rowID];
		[self _savePreview:preview forMessage:message atPath:path];
		return;
	}
	for (MCOIMAPMessagePart *attachment in [(MCOIMAPMessage *)message htmlInlineAttachments]) {
		BOOL hasData = [self _hasDataForAttachmentWithPartID:attachment.partID messageRowID:rowID];
		if (!hasData) {
			return;
		}
	}
	NSString *preview = [self _previewForMessage:message atPath:path messageRowID:rowID];
	[self _savePreview:preview forMessage:message atPath:path];
}

- (BOOL)_hasDataForAttachmentWithPartID:(NSString *)part_id messageRowID:(NSUInteger)rowID {
	BOOL result = NO;
	FMResultSet *queryResults = [self.connection executeQuery:@"select has_contents from attachment where message_id = ? and part_id = ?", @(rowID), part_id];
	if ([queryResults next]) {
		result = [queryResults longLongIntForColumn:@"has_contents"];
	}
	return result;
}

- (void)_savePreview:(NSString *)preview forMessage:(MCOAbstractMessage *)message atPath:(NSString *)path {
	NSData *previewData = [preview dataUsingEncoding:NSUTF8StringEncoding];
	if (previewData.length >= 512) {
		previewData = [previewData subdataWithRange:NSMakeRange(0, 512)];
	}
	[self.previewCache setData:previewData forKey:PSTIdentifierForMessage(message, path)];
}

- (NSString *)_previewForMessage:(MCOAbstractMessage *)message path:(NSString *)path {
	NSData *previewData = [self.previewCache dataForKey:PSTIdentifierForMessage(message, path)];
	if (previewData != nil) {
		NSUInteger len = previewData.length > 0x1ff ? 0x1ff : previewData.length;
		return [NSString stringWithCharacters:(void *)previewData.bytes length:len];
	}
	return nil;
}

- (NSString *)_previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path messageRowID:(NSUInteger)messageRowID {
	return [self _previewForMessage:message atPath:path messageRowID:messageRowID showLink:NO];
}

- (NSString *)_previewForMessage:(MCOAbstractMessage *)message atPath:(NSString *)path messageRowID:(NSUInteger)messageRowID showLink:(BOOL)showLink {
	if (![message isKindOfClass:[MCOIMAPMessage class]]) {
		return [self _previewForLocalMessage:(PSTLocalMessage *)message messageRowID:messageRowID showLink:showLink];
	}
	return [self _previewForIMAPMessage:(MCOIMAPMessage *)message atPath:path messageRowID:message showLink:showLink];
}

- (NSString *)_previewForLocalMessage:(PSTLocalMessage *)message messageRowID:(NSUInteger)messageRowID showLink:(BOOL)showLink {
//	if (message.attachments == nil) {
//		
//	} else {
//		return [self _previewStringForMessage:message showLink:showLink];
//	}
	return @"Preview For local Message";
}

- (NSString *)_previewForIMAPMessage:(MCOIMAPMessage *)message atPath:(NSString *)path messageRowID:(NSUInteger)messageRowID showLink:(BOOL)showLink {
	NSString *result = nil;
	if (message.attachments == nil) {
		result = [self _previewStringForMessage:message atPath:path showLink:showLink];
	} else {
		 result = [self _previewStringForMessage:message atPath:path showLink:showLink];
	}
	return result;
}

- (NSString *)_previewStringForMessage:(MCOIMAPMessage *)message atPath:(NSString *)path showLink:(BOOL)showLink {
	NSMutableString *result = [[NSMutableString alloc]init];
	for (MCOIMAPPart *attachment in message.mainPart.allAttachments) {
		
		NSData *textData = [self dataForAttachmentMessage:message atPath:path partID:attachment.partID filename:attachment.filename mimeType:attachment.mimeType];
		if (textData.bytes == NULL) {
			continue;
		}
		NSString *preview = [NSString stringWithCString:textData.bytes encoding:NSUTF8StringEncoding];
		if (preview.length == 0) {
			preview = [NSString stringWithCString:textData.bytes encoding:NSASCIIStringEncoding];
		}
		if (preview.length) [result appendString:[preview mco_flattenHTMLAndShowBlockquote:YES showLink:showLink]];
	}
	if ([result stringByConvertingHTMLToPlainText].length == 0) {
		if (message.allAttachments.count == 0) {
			result = @"This message has no content.".mutableCopy;
		} else {
			if ([message attachments].count == 1) {
				NSString *filename = [[[message attachments]objectAtIndex:0]filename];
				if (filename == nil) {
					filename = @"(no name)";
				}
				[result appendFormat:@"Attachment: %@", filename];
			} else {
				[result appendString:@"Attachments: "];
				for (int i = 0; i < [message attachments].count; i++) {
					NSString *filename = [[[message attachments]objectAtIndex:i]filename];
					if (filename == nil) {
						filename = @"(no name)";
					}
					if (i == 0) {
						[result appendString:filename];
					} else {
						[result appendFormat:@", %@", filename];
					}
				}
			}
		}
		
	}
	return [[result stringByConvertingHTMLToPlainText]copy];
}

- (void)cacheMessage:(MCOAbstractMessage *)message atRowIndex:(NSUInteger)rowID {
	if (message == nil) return;
	
	@synchronized(self.decodedMessageCache) {
		PSTSerializableMessage *serializedMessage = [PSTSerializableMessage serializableMessageWithMessage:message];
		[self.decodedMessageCache setObject:serializedMessage forKey:@(rowID)];
		[self.messagesCache setData:[NSKeyedArchiver archivedDataWithRootObject:serializedMessage] forIndex:rowID];
	}
}

- (PSTSerializableMessage *)lookupCachedMessageAtRowIndex:(NSUInteger)rowID {
	id result;
	@synchronized(self) {
		if ([self.decodedMessageCache objectForKey:[NSNumber numberWithUnsignedInteger:rowID]] == nil) {
			result = nil;
			if ([self _messageForData:[self.messagesCache dataForIndex:rowID]] != nil) {
				[self.decodedMessageCache setObject:[self _messageForData:[self.messagesCache dataForIndex:rowID]] forKey:[NSNumber numberWithUnsignedInteger:rowID]];
				result = [self _messageForData:[self.messagesCache dataForIndex:rowID]];
			}
		}
		else {
			result = [self.decodedMessageCache objectForKey:@(rowID)];
		}
	}
	return result;
}

- (void)removeMessageUIDFromIncomplete:(uint32_t)uid forPath:(NSString *)path {
	[[self _incompleteMessagesUIDsIndexSetForPath:path]removeIndex:uid];
	[self.uidsModified addObject:path];
}

- (void)_setLastUID:(long long)lastUID forPath:(NSString *)path {
	[self.lastUIDPathDict setObject:[NSNumber numberWithLongLong:lastUID] forKey:path];
}

- (void)commitMessageFlags:(MCOIMAPMessage *)message forFolder:(NSString *)folder {
	NSUInteger rowID = [self indexOfMessage:message atPath:folder];
	FMResultSet *result = [self.connection executeQuery:@"select flags from message where rowid = ?", @(rowID)];
	if ([result next]) {
		BOOL hasDiffFlags = NO;
		if (message.flags != [result intForColumn:@"flags"]) {
			hasDiffFlags = YES;
		} else {
			hasDiffFlags = NO;
		}
		PUISSANT_FMDB_ERROR_LOG
	}
}

- (void)_setMessageLabels:(MCOMessageFlag)messageFlags forUID:(uint32_t)uid path:(NSString *)path {
	@autoreleasepool {
		NSMutableDictionary *flagsDict = [[NSMutableDictionary alloc]init];
		[flagsDict setObject:[NSNumber numberWithInt:messageFlags] forKey:@"labels"];
		[self.labelsCache setData:[NSKeyedArchiver archivedDataWithRootObject:flagsDict] forKey:[NSString stringWithFormat:@"%@-%u", [path dmEncodedURLValue], uid]];
	}
}

- (NSString *)_folderPathForIdentifier:(NSUInteger)identifier {
	NSString *retVal = nil;
	@synchronized(self) {
		retVal = [self.folderPaths objectForKey:[NSNumber numberWithLongLong:identifier]];
	}
	if (retVal == nil) {
		if ([NSThread currentThread] == [NSThread mainThread]) {
			PSTLog(@"%@ failed getting path for identifier %lu", self.email, identifier);
			retVal = nil;
		}
		else {
			FMResultSet *query = [self.connection executeQuery:@"select path from mailbox where rowid = ?", [NSNumber numberWithUnsignedInteger:identifier]];
			if ([query next]) {
				retVal = [query stringForColumn:@"path"];
			}
			[query close];
			if (retVal != nil) {
				@synchronized(self) {
					[self.folderIdentifiersCache setObject:[NSNumber numberWithUnsignedInteger:identifier] forKey:retVal];
					[self.folderPaths setObject:[NSNumber numberWithUnsignedInteger:identifier] forKey:retVal];
				}
			}
		}
	}
	return retVal;
}

- (void)_removeMessageWithRowID:(long long)rowID {
	FMResultSet *resultSet = [self.connection executeQuery:@"select conversation_id, uid, folder_idx, is_local from message where rowid = ?", [NSNumber numberWithLongLong:rowID]];
	PUISSANT_FMDB_ERROR_LOG
	long long conversationID;
	uint32_t uid;
	long long mailboxID;
	BOOL isLocal;
	long long flag = 0;
	if (![resultSet next]) {
		conversationID = INT64_MAX;
		uid = UINT32_MAX;
		mailboxID = INT64_MAX;
		isLocal = NO;
		flag = INT64_MAX;
	} else {
		conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
		uid = (uint32_t)[resultSet longLongIntForColumn:@"uid"];
		mailboxID = [resultSet longLongIntForColumn:@"folder_idx"];
		isLocal = [resultSet longLongIntForColumn:@"is_local"];
	}
	NSString *folderPath = [self _folderPathForIdentifier:mailboxID] ;
	if (folderPath != nil) {
//		[self removeMessageUID:uid forPath:folderPath];
	}
	[resultSet close];
	if (flag != 0xff) {
		NSString *identifier = nil;
		if (isLocal) {
			MCOAbstractMessage *message = [self lookupCachedMessageAtRowIndex:rowID];
			if ([[self lookupCachedMessageAtRowIndex:rowID]isKindOfClass:[PSTLocalMessage class]]) {
				[(PSTLocalMessage *)[self lookupCachedMessageAtRowIndex:rowID]remove];
			}
			identifier = PSTIdentifierForLocalMessageID(message.header.messageID, folderPath);
		}
		else {
			identifier = PSTIdentifierForMessageID(uid, folderPath);
		}
		[self.previewCache removeDataForKey:identifier];
		[self.connection executeUpdate:@"delete from message where rowid = ?", @(rowID)];
		PUISSANT_FMDB_ERROR_LOG
		[self _storeRemoveMessageForRowID:rowID];
		[self _modifyRelationIDForRowID:rowID];
//		if (!isLocal) {
//			<#statements#>
//		}
	}
}

- (void)_modifyRelationIDForRowID:(NSUInteger)identifier {
	
}

- (void)invalidateMailbox:(NSString *)mailboxPath {
	if ([self.folderIdentifiersCache objectForKey:mailboxPath] == nil) return;
	else {
		@synchronized(self) {
			[self.folderIdentifiersCache removeObjectForKey:mailboxPath];
			[self.folderPaths removeObjectForKey:[NSNumber numberWithUnsignedInteger:[self _folderIdentifierForPath:mailboxPath]]];
		}
	}
}

- (void)_storeRemoveMessageForRowID:(NSUInteger)identifier {
	@synchronized(self) {
		[self.decodedMessageCache removeObjectForKey:@(identifier)];
		[self.messagesCache removeDataForIndex:identifier];
	}
}


- (PSTConversationCache *)cacheForConversationID:(NSUInteger)conversationID folderPath:(NSString *)folderPath otherFolderPath:(NSString *)otherFolderPath draftsFolderPath:(NSString *)draftsFolderPath sentMailFolderPath:(NSString *)sentMailFolderPath {
	return [self _conversationCacheForConversationID:conversationID folderID:[self identifierForFolderPath:folderPath] otherFolderID:[self identifierForFolderPath:otherFolderPath] inboxFolderID:[self identifierForFolderPath:@"INBOX"] draftsFolderID:[self identifierForFolderPath:draftsFolderPath] sentFolderID:[self identifierForFolderPath:sentMailFolderPath]];
}

- (PSTConversationCache *)_conversationCacheForConversationID:(NSUInteger)conversationID folderID:(NSUInteger)folderID otherFolderID:(NSUInteger)otherFolderID inboxFolderID:(NSUInteger)inboxFolderID draftsFolderID:(NSUInteger)draftsFolderID sentFolderID:(NSUInteger)sentFolderID {
	PSTConversationCache *cache = [self.conversationsCache[conversationID] dmUnarchivedData];
	[cache loadFromDatabase:self folderID:folderID otherFolderID:otherFolderID inboxFolderID:inboxFolderID draftsFolderID:draftsFolderID sentFolderID:sentFolderID];
	return cache;
}

PSTConversationCache *PSTConversationCacheForConversationID(NSUInteger conversationID, NSString *folderPath, NSString *otherFolderPath, NSString *draftsFolderPath, NSString *sentMailFolderPath, PSTDatabase *context) {	
	PSTConversationCache *cache = [context.conversationsCache[conversationID] dmUnarchivedData];
	[cache loadFromDatabase:context folderID:[context identifierForFolderPath:folderPath] otherFolderID:[context identifierForFolderPath:otherFolderPath] inboxFolderID:[context identifierForFolderPath:@"INBOX"] draftsFolderID:[context identifierForFolderPath:draftsFolderPath] sentFolderID:[context identifierForFolderPath:sentMailFolderPath]];
	return cache;
}

PSTConversationCache *PSTSearchConversationCacheForConversationID(NSUInteger conversationID, PSTDatabase *context) {
	PSTConversationCache *cache = [context.conversationsCache[conversationID] dmUnarchivedData];
	[cache resolveCachedSendersAndRecipients];
	return cache;
}

- (NSUInteger)indexOfMessage:(MCOAbstractMessage *)message atPath:(NSString *)folderPath {
	NSUInteger result = 0;
	if ([message isKindOfClass:[PSTLocalMessage class]]) {
		result = [self _rowIDForDraftMessageID:message.header.messageID draftFolderPath:((PSTLocalMessage *)message).folder.path];
	} else {
		if (folderPath != nil) {
			result = [self _rowIDForMessageUID:[(MCOIMAPMessage *)message uid] folderPath:folderPath];
		} else {
			return NSUIntegerMax;
		}
	}
	return result;
}

- (NSUInteger)_rowIDForDraftMessageID:(NSString *)messageID draftFolderPath:(NSString *)draftFolderPath {
	NSUInteger result = NSUIntegerMax;
	FMResultSet *resultSet = [self.connection executeQuery:@"select rowid from message indexed by message_msgid_idx where msgid = ? and folder_idx = ? and is_local = 1 limit 1", messageID, @([self _folderIdentifierForPath:draftFolderPath])];
	if ([resultSet next]) {
		result = [resultSet longLongIntForColumn:@"rowid"];
	}
	[resultSet close];
	return result;
}

- (NSUInteger)_rowIDForMessageUID:(uint32_t)messageUID folderPath:(NSString *)folderPath {
	NSUInteger result = NSUIntegerMax;
	FMResultSet *resultSet = [self.connection executeQuery:@"select rowid from message where uid = ? and folder_idx = ? limit 1", @(messageUID), @([self _folderIdentifierForPath:folderPath])];
	if ([resultSet next]) {
		result = [resultSet longLongIntForColumn:@"rowid"];
		[resultSet close];
	}
	[resultSet close];
	return result;
}

//- (NSArray *)duplicateMessagesForMessage:(MCOIMAPMessage *)message cache:(PSTConversationCache *)cache folders:(NSDictionary *)folders {
//	NSUInteger folderIdentifier = [self _folderIdentifierForPath:message.folder.path];
//	NSMutableArray *array = [NSMutableArray array];
//	for (PSTCachedMessage *messageCache in [self duplicateMessagesForUniqueIdentifier:[message uniqueMessageIdentifer]]) {
//		if (messageCache.folderID != folderIdentifier) {
//			if ([self lookupCachedMessageForRowID:messageCache.rowID]) {
//				if ([self folderPathForIdentifier:messageCache.folderID]) {
//					if ([folders objectForKey:[self _folderPathForIdentifier:messageCache.folderID]]) {
//						[messageCache setFolder:[folders objectForKey:[self _folderPathForIdentifier:messageCache.folderID]]];
//						[array addObject:messageCache];
//					}
//				}
//			}
//		}
//	}
//	return array;
//}

- (id)_messageForData:(NSData *)data {
	id result = nil;
	if (data != nil) {
		result = [data dmUnarchivedData];
	}
	if ([result isKindOfClass:[PSTLocalMessage class]]) {
		[(PSTLocalMessage *)result setFolderPath:self.localDraftsPath];
	}
	return result;
}

- (void)_updateConversationVisibilityWithMessage:(NSUInteger)rowID {
	[self _resetDiffingState];
	[self.invalidConversationRowIDs addIndex:rowID];
	FMResultSet *resultSet = [self.connection executeQuery:@"select conversation_id, folder_idx from message where rowid = ?", @(rowID)];
	if ([resultSet next]) {
		NSUInteger conversationID = [resultSet longLongIntForColumn:@"conversation_id"];
		NSUInteger mailboxID = [resultSet longLongIntForColumn:@"folder_idx"];
		[resultSet close];
		if (conversationID == NSUIntegerMax) {
			return;
		} else {
			[self _updateConversationVisibility:conversationID folderID:mailboxID];
		}
	} else {
		[resultSet close];
	}
}

- (void)_updateConversationVisibility:(NSUInteger)convoID folderID:(NSUInteger)folderIdentifier {
	@autoreleasepool {
		PSTConversationCache *pendingConversation = nil;
		NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
		if (_databaseFlags.conversationAllMessageIDsInvalid == NO) {
			pendingConversation = [self.pendingConversationCache objectForKey:@(convoID)];
			if (pendingConversation == nil) {
				pendingConversation = [[self.conversationsCache dataForIndex:convoID]dmUnarchivedData];
			}
			for (PSTCachedMessage *message in pendingConversation.messages) {
				[dictionary setObject:message forKey:@(message.rowID)];
			}
		}
		PSTConversationCache *newConversation = [[PSTConversationCache alloc]init];
		if (pendingConversation != nil) {
			[newConversation setSubject:pendingConversation.subject];
		}
		BOOL validConversation = NO;
		BOOL isFacebookMessage = NO;
		BOOL isTwitterNotification = NO;
		if (_databaseFlags.conversationRowIDAdded) {
			FMResultSet *resultSet = [self.connection executeQuery:@"select rowid from message where conversation_id = ?", @(convoID)];
			validConversation = [resultSet next];
			[resultSet close];
			resultSet = [self.connection executeQuery:@"select rowid, uid, folder_idx from message where conversation_id = ? and deleted = 0 and is_deleted = 0", @(convoID)];
			PUISSANT_FMDB_ERROR_LOG
			int idx = 0;
			while ([resultSet next]) {
				idx++;
				if (![self.invalidConversationRowIDs containsIndex:convoID]) {
					long long rowID = [resultSet longLongIntForColumn:@"rowid"];
					PSTSerializableMessage *message = [self lookupCachedMessageAtRowIndex:rowID];
					if (!message) {
						continue;
					}
					if (message.uid != 0) {
						if (!isFacebookMessage && [message isFacebookNotification]) {
							isFacebookMessage = YES;
						} else if (!isTwitterNotification && [message isTwitterNotification]) {
							isTwitterNotification = YES;
						}
						[newConversation addMessage:message rowID:rowID folderID:folderIdentifier];
					}
				}
			}
			[resultSet close];
		}
		if (validConversation == NO || newConversation.messages.count == 0) {
			[self.connection executeUpdate:@"delete from conversation where rowid = ?", @(convoID)];
			PUISSANT_FMDB_ERROR_LOG
			[self.conversationsCache removeDataForIndex:convoID];
			[self.pendingConversationCache removeObjectForKey:@(convoID)];
			[self.connection executeUpdate:@"delete from conversation_thread_id where conversation_id = ?", @(convoID)];
			PUISSANT_FMDB_ERROR_LOG
			[self.connection executeUpdate:@"delete from conversation_data where conversation_id = ?", @(convoID)];
			PUISSANT_FMDB_ERROR_LOG
			[self _resetDiffingState];
			return;
		}
		[self.pendingConversationCache setObject:newConversation forKey:@(convoID)];
		if (folderIdentifier != 0) {
			if (convoID != 0) {
				FMResultSet *visibleQuery = [self.connection executeQuery:@"select visible from conversation_data where conversation_id = ? and folder_idx = ?", @(convoID), @(folderIdentifier)];
				BOOL noVisibility = NO;
				BOOL flag = 0;
				if (![visibleQuery next]) {
					flag = 1;
				} else {
					int counter = 0;
					while ([visibleQuery next]) {
						flag = [visibleQuery intForColumn:@"visible"];
						counter--;
					}
					noVisibility = (counter == 0 ? YES : NO);
				}
				[visibleQuery close];
				[newConversation resolveDateUsingFolder:folderIdentifier];
//				if (noVisibility == NO) {
					if (flag == 0) {
						[self.connection executeUpdate:@"update conversation_data set visible = 1, most_recent_message_date = ? where conversation_id = ? and folder_idx = ?", [NSDate date], @(convoID), @(folderIdentifier)];
					} else {
						[self.connection executeUpdate:@"update conversation_data set most_recent_message_date = ? where conversation_id = ? and folder_idx = ?", [NSDate date], @(convoID), @(folderIdentifier)];
					}
					if (![self.connection hadError]) {
						[self _resetDiffingState];
						[self.connection executeUpdate:@"insert into conversation_data (conversation_id, folder_idx, most_recent_message_date, visible, action_step, is_facebook, is_twitter) values (?, ?, ?, 1, 0, ?, ?)", @(convoID), @(folderIdentifier), newConversation.date, @(isFacebookMessage), @(isTwitterNotification)];
						if ([self.connection hadError]) {
							PUISSANT_FMDB_ERROR_LOG;
							[self _resetDiffingState];
						}
						[self _resetDiffingState];
						return;
					}
					PUISSANT_FMDB_ERROR_LOG;
					return;
//				}
				
			}
			[self.connection executeUpdate:@"delete from conversation_data where conversation_id = ? and folder_idx = ?", @(convoID), @(folderIdentifier)];
			if (![self.connection hadError]) {
				[self _resetDiffingState];
			}
			PUISSANT_FMDB_ERROR_LOG;
			[self _resetDiffingState];
			return;
		}
		[self.connection executeUpdate:@"delete from conversation_data where conversation_id = ?", @(convoID)];
		if (![self.connection hadError]) {
			[self _resetDiffingState];
		}
		PUISSANT_FMDB_ERROR_LOG;
		[self _resetDiffingState];
		return;
	}
	
}

- (void)_resetDiffingState {
	_databaseFlags.conversationRowIDAdded = NO;
	_databaseFlags.conversationAllMessageIDsInvalid = NO;
	[self.invalidConversationRowIDs removeAllIndexes];
	[self.invalidConversationMessageIDs removeAllObjects];
}

- (NSArray *)duplicateMessagesForUniqueIdentifier:(NSString *)identifier {
	return [self.duplicates objectForKey:identifier];
}

#pragma mark - File path getters

- (NSString *)_pathForMessage:(MCOAbstractMessage *)message path:(NSString *)path {
	NSString *result = nil;
	if ([message isKindOfClass:[MCOIMAPMessage class]]) {
		result = [self _pathForMessageUID:((MCOIMAPMessage *)message).uid path:path];
	} else if ([message isKindOfClass:[PSTLocalMessage class]]) {
		result = [self _pathForLocalMessageID:message.header.messageID path:path];
	} else {
//		result = [self _pathForMessageUID:((PSTPopMessage *)message).uid path:path];
	}
	return result;
}

- (NSString *)_pathForLocalMessageID:(NSString *)messageID path:(NSString *)path {
	return [[[self.path stringByAppendingPathComponent:@"LocalDrafts"]stringByAppendingPathComponent:[path dmEncodedURLValue]]stringByAppendingPathComponent:[messageID dmEncodedURLValue]];
}

- (NSString *)_pathForMessageUID:(unsigned long)uid path:(NSString *)path {
	return [[[self.path stringByAppendingPathComponent:@"Cache"]stringByAppendingPathComponent:[path dmEncodedURLValue]]stringByAppendingPathComponent:[NSString stringWithFormat:@"%lu", uid]];
}

#pragma mark - Identifiers

NSString *PSTIdentifierForConversationCachePreview(PSTConversationCache *cache) {
	if (cache.flags & MCOMessageFlagDraft) {
		return PSTIdentifierForLocalMessageID(cache.previewMessageID, cache.previewPath);
	} else {
		return PSTIdentifierForMessageID(cache.previewUID, cache.previewPath);
	}
}

static NSString *PSTIdentifierForMessage(MCOAbstractMessage *message, NSString *path) {
	if ([message isKindOfClass:[MCOIMAPMessage class]] || [message isKindOfClass:[PSTCachedMessage class]]  || [message isKindOfClass:[PSTSerializableMessage class]]) {
		return PSTIdentifierForMessageID(((MCOIMAPMessage *)message).uid, path);
	}
	return nil;
}

static NSString *PSTIdentifierForLocalMessageID(NSString *messageID, NSString *path) {
	return  [[path dmEncodedURLValue]stringByAppendingPathComponent:[@"LocalDrafts" stringByAppendingPathComponent:[messageID dmEncodedURLValue]]];
}

static NSString *PSTIdentifierForMessageID(uint32_t uid, NSString *path) {
	return [[@"Cache" stringByAppendingPathComponent:[path dmEncodedURLValue]] stringByAppendingPathComponent:[NSString stringWithFormat:@"%u", uid]];
}

static NSString *PSTIdentifierForAttachmentWithUID(uint32_t uid, NSString *path, NSString *part_id) {
	return [PSTIdentifierForMessageID(uid, path) stringByAppendingPathComponent:part_id];
}

static NSString *PSTIdentifierForAttachmentWithPath(MCOAbstractMessage *message, NSString *part_id, NSString *path) {
	return [PSTIdentifierForMessage(message, path) stringByAppendingPathComponent:part_id];
}

@end
