//
//  PSTTCHashFile.m
//  Puissant
//
//  Created by Robert Widmann on 11/14/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTLevelDBCache.h"
#include <libkern/OSAtomic.h>

#define PSTSliceFromData(_data_) (Slice((char *)[_data_ bytes], [_data_ length]))
#define PSTDataFromSlice(_slice_) ([NSData dataWithBytes:_slice_.data() length:_slice_.size()])

#define PSTSliceFromString(_string_) (Slice((char *)[_string_ UTF8String], [_string_ lengthOfBytesUsingEncoding:NSUTF8StringEncoding]))
#define PSTStringFromSlice(_slice_) ([[NSString alloc] initWithBytes:_slice_.data() length:_slice_.size() encoding:NSUTF8StringEncoding])

using namespace leveldb;

typedef NS_ENUM(NSUInteger, PSTCacheSyncState) {
	PSTCacheSyncStateNormal,
	PSTCacheSyncStateReadyForTransaction,
	PSTCacheSyncStateInTransaction,
	PSTCacheSyncStateDeallocating,
};

OSSpinLock lock = OS_SPINLOCK_INIT;
OSSpinLock open_lock = OS_SPINLOCK_INIT;

@interface PSTLevelDBCache ()

@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) BOOL opened;
@property DB *database;

@end

@implementation PSTLevelDBCache {
	ReadOptions readOptions;
	WriteOptions writeOptions;
	size_t bufferSize;
	
	NSUInteger syncState;
}

- (id)initWithPath:(NSString *)path {
	NSParameterAssert(path);
	
	self = [super init];
	
	_path = path;
	//Won't replace the given path if it already exists
	[[NSFileManager defaultManager] createDirectoryAtPath:_path withIntermediateDirectories:YES attributes:nil error:nil];
	syncState = PSTCacheSyncStateNormal;

	return self;
}

- (BOOL)open {
	Options options;
	options.create_if_missing = true;
	options.write_buffer_size = bufferSize;
	
	DB *theDB;
	
	Status status = DB::Open(options, [self.path UTF8String], &theDB);
	
	if(!status.ok()) {
		NSLog(@"Problem creating LevelDB database: %s", status.ToString().c_str());
	} else {
		self.database = theDB;
	}
	readOptions.fill_cache = false;
	writeOptions.sync = true;
	
	return status.ok();
}

- (void)setData:(NSData *)data forKey:(NSString *)key {
	if (syncState != PSTCacheSyncStateDeallocating) {
		Status status = self.database->Put(writeOptions, PSTSliceFromString(key), PSTSliceFromData(data));
	}
}

- (NSData *)dataForKey:(NSString *)key {
	NSData *result = nil;

	if (syncState != PSTCacheSyncStateDeallocating) {
		std::string tempValue;
		Status status = self.database->Get(readOptions, PSTSliceFromString(key), &tempValue);
		
		if(!status.IsNotFound()) {
			if(status.ok()) {
				Slice value = tempValue;
				result = PSTDataFromSlice(value);
			}
		}
	}
	return result;
}

- (void)removeDataForKey:(NSString *)key {
	Status status = self.database->Delete(writeOptions, PSTSliceFromString(key));
}


- (void)close {
	delete self.database;
}

@end

@implementation PSTLevelDBCache (PSTExtendedCache)

- (BOOL)hasDataForKey:(NSString *)key {
	BOOL result = NO;
	
	std::string tempValue;
	Status status = self.database->Get(readOptions, PSTSliceFromString(key), &tempValue);
	
	if(!status.IsNotFound()) {
		if(status.ok()) {
			result = YES;
		}
	}
	
	return result;
}

@end

@implementation PSTLevelDBCache (PSTSubscripting)

- (id)objectForKeyedSubscript:(NSString*)key {
	return [self dataForKey:key];
}

- (void)setObject:(NSData*)obj forKeyedSubscript:(NSString*)key {
	[self setData:obj forKey:key];
}

@end
