//
//  PSTMessageIndex.m
//  Puissant
//
//  Created by Robert Widmann on 11/13/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTMessageIndex.h"
#import "FMDatabase.h"
#import "PSTDystopiaSearchIndex.h"
#import "PSTSearchParser.h"

#ifdef DEBUG
#define DOTMAIL_FMDB_ERROR_LOG \
if ([self.database hadError]) { \
PSTLog(@"PSTMessageDatabase error %d: %@", [self.database lastErrorCode], [self.database lastErrorMessage]); \
}
#else 
#define DOTMAIL_FMDB_ERROR_LOG 
#endif 

@interface PSTMessageIndex ()

@property (nonatomic, strong) PSTDystopiaSearchIndex *index;
@property (nonatomic, strong) PSTSearchParser *searchParser;

@end

@implementation PSTMessageIndex {
	NSInteger _changeCount;
	BOOL _opened;
	BOOL _searchStarted;
	BOOL _cancelSearch;
}

- (id)init {
	self = [super init];
	
	//	_settingUseDystopiaIndexer = YES;
	
	return self;
}

- (id)_indexWithFilename:(NSString *)name {
	return [[PSTDystopiaSearchIndex alloc] initWithPath:name];
}

- (BOOL)open {
	return YES;
}

- (BOOL)_openIfNeeded {
	return [self _openIfNeededAndCrashIfFail:YES];
}

- (BOOL)openAndCheckConsistency {
	return [self _openIfNeededAndCrashIfFail:NO];
}

- (BOOL)_openIfNeededAndCrashIfFail:(BOOL)crash {
	if (_opened) {
		return YES;
	}
	NSString *indexesDir = [self.path stringByAppendingPathComponent:@"Indexes"];
	[NSFileManager.defaultManager createDirectoryAtPath:indexesDir withIntermediateDirectories:YES attributes:nil error:nil];
	_index = [self _indexWithFilename:[indexesDir stringByAppendingPathComponent:@"global.index"]];
	[_index open];
	_opened = YES;
	return YES;
}

- (void)addMessage:(NSUInteger)messageID from:(NSString *)from recipient:(NSString *)recipient subject:(NSString *)subject {
	[self.database executeUpdate:@"insert into message_header_fts (message_id, from_address, recipient, subject) values (?, ?, ?, ?)", @(messageID), from, recipient, subject];
	DOTMAIL_FMDB_ERROR_LOG
	[self.database executeUpdate:@"insert into message_contents_fts (message_id, contents) values (?, ?)", @(messageID), [NSString stringWithFormat:@"%@ %@ %@", from, recipient, subject]];
	DOTMAIL_FMDB_ERROR_LOG
	_changeCount++;
	[self _flushIfNeeded];
}

- (void)removeMessage:(NSUInteger)messageID {
	[self.database executeUpdate:@"delete from message_contents_fts where message_id = ?", @(messageID)];
	[self.database executeUpdate:@"delete from message_header_fts where message_id = ?", @(messageID)];
	[self.database executeUpdate:@"delete from message_delete_fts where message_id = ?", @(messageID)];
	_changeCount++;
	[self _flushIfNeeded];
}

- (void)updateMessage:(NSUInteger)messageID contents:(NSString *)contents {
	[self.database executeUpdate:@"delete from message_contents_fts where message_id = ?", @(messageID)];
	[self.database executeUpdate:@"insert into message_contents_fts (message_id, contents) values (?, ?)", @(messageID), contents];
	_changeCount++;
	[self _flushIfNeeded];
}

- (void)updateMessage:(NSUInteger)messageID attachments:(NSString *)contents {
	[self.database executeUpdate:@"delete from message_attachments_fts where message_id = ?", @(messageID)];
	[self.database executeUpdate:@"insert into message_attachments_fts (message_id, attachments) values (?, ?)", @(messageID), contents];
	_changeCount++;
	[self _flushIfNeeded];
}

- (void)optimizeIndex {
	[self _flush];
}

- (void)_flushIfNeeded {
	if (_changeCount < 100) {
		return;
	}
	[self _flush];
}

// TODO
- (void)_flush {
	FMResultSet *results = [self.database executeQuery:@"select * from message_delete_fts"];
	while ([results next]) {
		[self _openIfNeeded];
		
	}
	[results close];
	
	results = [self.database executeQuery:@"select * from message_header_fts"];
	while ([results next]) {
		[self _openIfNeeded];
		
	}
	[results close];
	
	results = [self.database executeQuery:@"select * from message_contents_fts"];
	while ([results next]) {
		[self _openIfNeeded];
		
	}
	[results close];
	
	results = [self.database executeQuery:@"select * from message_attachments_fts"];
	while ([results next]) {
		[self _openIfNeeded];
		
	}
	[results close];
}

- (void)close {
	[_index close];
	_opened = NO;
}

- (void)save {
	[_index save];
	
}

- (void)cancelSearch {
	@synchronized(self) {
		if (_searchStarted) {
			[_index cancelSearch];
			_cancelSearch = YES;
		}
	}
}

- (BOOL)isSearchCancelled {
	BOOL result = NO;
	@synchronized(self) {
		result = _cancelSearch;
	}
	return result;
}

PUISSANT_TODO(Implement SQL message index)
- (NSData *)_metaDataForMessageRowID:(NSUInteger)messageID {
	return nil;
}

- (NSData *)_messageForMessageRowID:(NSUInteger)messageID {
	return nil;
}

- (NSArray *)conversationsForSearchedTerms:(NSArray *)searchTerms searchKind:(NSInteger)searchKind mainFolders:(NSDictionary *)mainFolders allFoldersIDs:(NSDictionary *)folderIDs mode:(NSInteger)mode limit:(NSUInteger)limit returnedEverything:(BOOL)returningEverything {
	if (_searchParser == nil) {
		_searchParser = [[PSTSearchParser alloc] init];
	}
	[_searchParser parseTerms:searchTerms];
	return [self _conversationsUsingCurrentPraserForSearchKind:searchKind mainFolders:mainFolders allFolderIDs:folderIDs mode:mode limit:limit returnedEverything:returningEverything];
}

- (NSArray *)_conversationsUsingCurrentPraserForSearchKind:(NSInteger)searchKind mainFolders:(NSDictionary *)mainFolders allFolderIDs:(NSDictionary *)folderIDs mode:(NSInteger)mode limit:(NSUInteger)limit returnedEverything:(BOOL)returningEverything {
	return @[];
}

@end
