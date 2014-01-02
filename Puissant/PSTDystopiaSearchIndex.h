//
//  PSTDystopiaSearchIndex.h
//  Puissant
//
//  Created by Robert Widmann on 11/13/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TokyoCabinet/dystopia.h>

typedef NS_ENUM(NSUInteger, PSTSearchMetaDatabaseType) {
	PSTSearchMetaDatabaseTypeContent = 0,
	PSTSearchMetaDatabaseTypeFrom,
	PSTSearchMetaDatabaseTypeRecipient,
	PSTSearchMetaDatabaseTypeSubject,
	PSTSearchMetaDatabaseTypeAttachment
};


@interface PSTDystopiaSearchIndex : NSObject

@property (nonatomic, assign) TCIDB *database;
@property (nonatomic, assign) PSTSearchMetaDatabaseType type;

- (id)initWithPath:(NSString *)path;

- (BOOL)open;

- (NSArray *)searchWithTerms:(NSArray *)searchTerms searchBlock:(NSString *(^)(PSTDystopiaSearchIndex *index, NSString *key))searchBlock;

- (void)setString:(NSString *)string forKey:(NSString *)aKey;
- (void)removeKey:(NSString *)key;

- (void)cancelSearch;

- (BOOL)save;
- (void)close;

@end
