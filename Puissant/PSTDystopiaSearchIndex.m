//
//  PSTDystopiaSearchIndex.m
//  Puissant
//
//  Created by Robert Widmann on 11/13/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTDystopiaSearchIndex.h"

@interface PSTDystopiaSearchIndex ()

@property (nonatomic, copy) NSString *path;

@end

@implementation PSTDystopiaSearchIndex

- (id)initWithPath:(NSString *)path {
	if (self = [super init]) {
		_path = path;
	}
	return self;
}

- (BOOL)open {
	BOOL result = YES;
	self.database = tcidbnew();
	tcidbtune(self.database, 1000000, 1000000, 0, IDBTLARGE);
	if (!tcidbopen(self.database, self.path.fileSystemRepresentation, (IDBOREADER | IDBOWRITER | IDBOCREAT))) {
		tcidbclose(self.database);
		tcidbdel(self.database);
		self.database = NULL;
		result = NO;
	}
	return result;
}

- (void)setString:(NSString *)string forKey:(NSString *)aKey {
	tcidbput(self.database, [self metaDatabaseIntFromKey:aKey], string.UTF8String);
}

- (void)removeKey:(NSString *)aKey {
	tcidbout(self.database, [self metaDatabaseIntFromKey:aKey]);
}

- (NSArray *)searchWithTerms:(NSArray *)searchTerms searchBlock:(NSString *(^)(PSTDystopiaSearchIndex *index, NSString *key))searchBlock {
	NSParameterAssert(searchBlock != nil);
	
	NSMutableArray *completeTerms = [[NSMutableArray alloc]init];
	for (NSString *term in searchTerms) {
		[completeTerms addObjectsFromArray:[term componentsSeparatedByString:@" "]];
	}
	NSMutableSet *currentSet = nil;
	for (NSString *term in completeTerms) {
		if (term.length) {
			int outResultCount = 0;
			uint64_t *res = NULL;
			res = tcidbsearch(self.database, term.UTF8String, 0, &outResultCount);
			NSMutableSet *results = [[NSMutableSet alloc]init];
			if (outResultCount != 0) {
				for (NSUInteger i = 0; i < outResultCount; i++) {
//					[results addObject:[self prefixFromMetaDatabaseType:res[i]]];
				}
			}
			if (!currentSet) {
				currentSet = results;
			} else {
				[currentSet intersectSet:results];
			}
		}
	}
	if (!currentSet) {
		currentSet = [NSMutableSet set];
	}
	NSMutableArray *result = @[].mutableCopy;
	for (NSString *prefix in [currentSet allObjects]) {
		NSString *parsedResult = searchBlock(self, prefix);
		if (parsedResult) {
			[result addObject:parsedResult];
		}
	}
	return result;
}

- (uint64_t)metaDatabaseIntFromKey:(NSString *)key {
	int hasher = 0;
	long long strCode = 0;
	if ([key hasPrefix:@"ctnt."]) {
		strCode = [key substringFromIndex:5].longLongValue;
		hasher = 0;
	} else if ([key hasPrefix:@"from."]) {
		strCode = [key substringFromIndex:5].longLongValue;
		hasher = 1;
	} else if ([key hasPrefix:@"recip."]) {
		strCode = [key substringFromIndex:5].longLongValue;
		hasher = 2;
	} else if ([key hasPrefix:@"subj."]) {
		strCode = [key substringFromIndex:5].longLongValue;
		hasher = 3;
	} else if ([key hasPrefix:@"attch."]) {
		strCode = [key substringFromIndex:6].longLongValue;
		hasher = 4;
	} else {
		NSAssert(0, @"Invalid search type. Cannot generate key.");
		return 0;
	}
	return strCode << 4 | hasher;
}

- (NSString *)metaDatabaseKeyFromInt:(uint64_t)type {
	NSString *prefix = @"";
	switch ((type >> 4) &~ 4) {
		case PSTSearchMetaDatabaseTypeAttachment:
			prefix = @"attch.";
			break;
		case PSTSearchMetaDatabaseTypeContent:
			prefix = @"ctnt.";
			break;
		case PSTSearchMetaDatabaseTypeFrom:
			prefix = @"from.";
			break;
		case PSTSearchMetaDatabaseTypeRecipient:
			prefix = @"recip.";
			break;
		case PSTSearchMetaDatabaseTypeSubject:
			prefix = @"subj.";
			break;
		default:
			NSAssert(0, @"Invalid search type. Cannot generate key.");
			break;
	}
	
	return [prefix stringByAppendingFormat:@"%lli", (type >> 4)];
}

- (BOOL)save {
	return tcidbsync(self.database);
}

- (void)close {
	if (self.database != NULL) {
		tcidbclose(self.database);
		tcidbdel(self.database);
		self.database = NULL;
	}
}

- (void)cancelSearch {
	
}


@end