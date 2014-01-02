//
//  CFIUserDefaults.m
//  UserDefaultsPerformanceSuite
//
//  Created by Robert Widmann on 3/24/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTUserDefaults.h"
#include <pthread.h>

#ifdef TARGET_OS_MAC
#ifdef CFI_EXPERIMENTAL_ATOMIC_SINGLETONS
#import <libkern/OSAtomic.h>
static void * volatile sharedInstance = nil;
#endif
#endif

using namespace leveldb;

#define CFISliceFromData(_data_) (Slice((char *)[_data_ bytes], [_data_ length]))
#define CFIDataFromSlice(_slice_) ([NSData dataWithBytes:_slice_.data() length:_slice_.size()])

#define CFISliceFromString(_string_) (Slice((char *)[_string_ UTF8String], [_string_ lengthOfBytesUsingEncoding:NSUTF8StringEncoding]))
#define CFIStringFromSlice(_slice_) ([[[NSString alloc] initWithBytes:_slice_.data() length:_slice_.size() encoding:NSUTF8StringEncoding]autorelease])

#if __has_feature(objc_arc)
#define CFI_SAFEBRIDGE(x) (__bridge x)
#define CFI_SAFEAUTORELEASE(x) x
#define CFI_SAFERELEASE(x)
#define CFI_SAFERETAIN(x) x
#define CFI_SAFEDEALLOC
#else
#define CFI_SAFEBRIDGE(x) (x)
#define CFI_SAFEAUTORELEASE(x) [x autorelease]
#define CFI_SAFERELEASE(x) [x release]
#define CFI_SAFERETAIN(x) [x retain]
#define CFI_SAFEDEALLOC [super dealloc]
#endif

NSString * const PSTUserDefaultsDidChangeNotification = @"PSTUserDefaultsDidChangeNotification";

static Class stringClass;
static Class dataClass;
static Class dictClass;
static Class arrayClass;

//Shamelessly taken from the NULDB repository.  Thanks to the guys at NULayer for the awesome
//framework, and for the cool implementation of a dynamic @encode().
static NSData *CFIEncode(id<NSCoding>object) {
	char type = 'o';
	
	if([(id)object isKindOfClass:stringClass])    type = 's';
	else if([(id)object isKindOfClass:dataClass]) type = 'd';
	else if([(id)object isKindOfClass:dictClass] || [(id)object isKindOfClass:arrayClass]) type = 'h';
	
	
	NSMutableData *d = [NSMutableData dataWithBytes:&type length:1];
	
	switch (type) {
		case 's':
			[d appendData:[(NSString *)object dataUsingEncoding:NSUTF8StringEncoding]];
			break;
			
		case 'd':
			[d appendData:(NSData *)object];
			break;
			
		case 'h':
			[d appendData:[NSPropertyListSerialization dataWithPropertyList:(id)object format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL]];
			break;
			
		default:
			[d appendData:[NSKeyedArchiver archivedDataWithRootObject:object]];
			break;
	}
	
	return d;
}

static id CFIDecode(NSData *data) {
	
	NSData *value = [data subdataWithRange:NSMakeRange(1, [data length] - 1)];
	char type;
	[data getBytes:&type length:1];
	switch (type) {
		case 's':
			return CFI_SAFEAUTORELEASE([[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding]);
			break;
			
		case 'd':
			return value;
			break;
			
		case 'h':
			return [NSPropertyListSerialization propertyListWithData:value options:NSPropertyListImmutable format:NULL error:NULL];
			break;
			
		default:
			return [NSKeyedUnarchiver unarchiveObjectWithData:value];
			break;
	}
	return nil;
}

static inline Slice NULDBSliceFromObject(id<NSCoding> object) {
	if(!object) return Slice();
	
	NSData *d = CFIEncode(object);
	return Slice((const char *)[d bytes], (size_t)[d length]);
}

static inline id NULDBObjectFromSlice(Slice &slice) {
	return CFIDecode([NSData dataWithBytes:slice.data() length:slice.size()]);
}

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

@interface PSTUserDefaults ()

@property (nonatomic, copy) NSMutableDictionary *innerHash;
@property (nonatomic, copy) NSDictionary *registeredDefaults;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) NSUInteger transactionLock;
@property (nonatomic, assign) BOOL opened;
@property DB *database;

@end

@implementation PSTUserDefaults {
	ReadOptions readOptions;
	WriteOptions writeOptions;
	size_t bufferSize;
}

+ (void)initialize {
	stringClass = [NSString class];
	dataClass = [NSData class];
	dictClass = [NSDictionary class];
	arrayClass = [NSArray class];
}

+ (instancetype)standardUserDefaults {
	PUISSANT_SINGLETON_DECL(PSTUserDefaults);
}

+ (void)resetStandardUserDefaults {
	PSTUserDefaults *dbConnection = [self standardUserDefaults];
	dbConnection.database = nil;
	[NSFileManager.defaultManager removeItemAtPath:dbConnection.path error:nil];
	[dbConnection open];
}

- (void)flushClosed {
	delete self.database;
	self.database = NULL;
}

- (NSDictionary *)dictionaryRepresentation {
	return self.registeredDefaults;
}

- (void)registerDefaults:(NSDictionary *)registrationDictionary {
	self.registeredDefaults = registrationDictionary;
	[NSNotificationCenter.defaultCenter postNotificationName:PSTUserDefaultsDidChangeNotification object:nil];
}

- (id)init {
	self = [super init];
	
	self.path = [@"~/Library/Application Support/DotMail/Preferences.cfipref" stringByExpandingTildeInPath];
	//Won't replace the given path if it already exists
	[[NSFileManager defaultManager] createDirectoryAtPath:_path withIntermediateDirectories:YES attributes:nil error:nil];
	[self open];
	
	return self;
}

- (id)initWithUser:(NSString *)username {
	@throw [NSException exceptionWithName:@"CFIDeprecatedInitializerException"
								   reason:@"-initWithUser: has been deprecated in favor of +standardUserDefaults"
								 userInfo:nil];
	return nil;
}

- (void)dealloc {
	self.path = nil;
	CFI_SAFERELEASE(self.registeredDefaults);
	self.registeredDefaults = nil;
	CFI_SAFEDEALLOC;
}

- (BOOL)open {
	bufferSize = 1024;
	Options options;
	options.create_if_missing = true;
	options.write_buffer_size = 1 << 22;
	
	DB *theDB;
	
	Status status = DB::Open(options, [self.path UTF8String], &theDB);
	
	if(!status.ok())
		NSLog(@"Problem creating LevelDB database: %s", status.ToString().c_str());
	else
		self.database = theDB;
	
	readOptions.fill_cache = false;
	writeOptions.sync = true;
	
	return status.ok();
}

- (id<NSCoding>)objectForKey:(NSString *)defaultName {
	id result = [self.registeredDefaults objectForKey:defaultName];
	pthread_mutex_lock(&lock);
	
	std::string tempValue;
	Status status = self.database->Get(readOptions, CFISliceFromString(defaultName), &tempValue);
	
	if(!status.IsNotFound()) {
		if(status.ok()) {
			Slice value = tempValue;
			result = CFIDataFromSlice(value);
		}
	}
	pthread_mutex_unlock(&lock);
	return result;
}

- (NSString *)stringForKey:(NSString *)defaultName {
	id result = [self objectForKey:defaultName];
	
	if ([[result class] isKindOfClass:[NSString class]]) {
		return result;
	}
	return nil;
}

- (NSArray *)arrayForKey:(NSString *)defaultName {
	id result = [self objectForKey:defaultName];
	
	if ([[result class] isKindOfClass:[NSArray class]]) {
		return result;
	}
	return nil;
}

- (NSDictionary *)dictionaryForKey:(NSString *)defaultName {
	id result = [self objectForKey:defaultName];
	
	if ([[result class] isKindOfClass:[NSArray class]]) {
		return result;
	}
	return nil;
}

- (NSData *)dataForKey:(NSString *)defaultName {
	id result = [self objectForKey:defaultName];
	
	if ([[result class] isKindOfClass:[NSData class]]) {
		return result;
	}
	return nil;
}

- (NSArray *)stringArrayForKey:(NSString *)defaultName {
	id result = [self objectForKey:defaultName];
	
	if ([[result class] isKindOfClass:[NSArray class]]) {
		return result;
	}
	return nil;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
	id result = [self objectForKey:defaultName];
	
	if (result == nil) {
		return (NSInteger)result;
	}
	if ([[result class] isKindOfClass:[NSNumber class]]) {
		return [result integerValue];
	}
	else if ([[result class] isKindOfClass:[NSString class]]) {
		return [result integerValue];
	}
	return 0;
}

- (float)floatForKey:(NSString *)defaultName {
	id result = [self objectForKey:defaultName];
	
	if (result == nil) {
		return (float)nil;
	}
	if ([[result class] isKindOfClass:[NSNumber class]]) {
		return [result floatValue];
	}
	else if ([[result class] isKindOfClass:[NSString class]]) {
		return [result floatValue];
	}
	return 0;
}

- (double)doubleForKey:(NSString *)defaultName {
	id result = [self objectForKey:defaultName];
	
	if (result == nil) {
		return (double)nil;
	}
	if ([[result class] isKindOfClass:[NSNumber class]]) {
		return [result doubleValue];
	}
	else if ([[result class] isKindOfClass:[NSString class]]) {
		return [result doubleValue];
	}
	return 0;
}

- (BOOL)boolForKey:(NSString *)defaultName {
	id obj = [self objectForKey:defaultName];
	
	BOOL result = NO;
	
	if (obj != nil) {
		if ([[obj class] isKindOfClass:[NSNumber class]]) {
			return [obj boolValue];
		}
		else if ([[obj class] isKindOfClass:[NSString class]]) {
			BOOL equalToYes = [obj isEqualToString:@"YES"];
			result = equalToYes;
		}
	}
	
	return result;
}

- (NSURL *)URLForKey:(NSString *)defaultName {
	id result = [self objectForKey:defaultName];
	
	if (result == nil) {
		return result;
	}
	if ([[result class] isKindOfClass:[NSURL class]]) {
		return result;
	}
	else if ([[result class] isKindOfClass:[NSString class]]) {
		return [NSURL fileURLWithPath:[result stringByExpandingTildeInPath]];
	}
	return nil;
}

- (void)setObject:(id<NSCoding>)value forKey:(NSString *)defaultName {
	pthread_mutex_lock(&lock);
	Status status = self.database->Put(writeOptions, NULDBSliceFromObject(value), CFISliceFromString(defaultName));
	pthread_mutex_unlock(&lock);
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
	pthread_mutex_lock(&lock);
	Status status = self.database->Put(writeOptions, NULDBSliceFromObject([NSNumber numberWithInteger:value]), CFISliceFromString(defaultName));
	pthread_mutex_unlock(&lock);
}

- (void)setFloat:(float)value forKey:(NSString *)defaultName {
	pthread_mutex_lock(&lock);
	Status status = self.database->Put(writeOptions, NULDBSliceFromObject([NSNumber numberWithFloat:value]), CFISliceFromString(defaultName));
	pthread_mutex_unlock(&lock);
}

- (void)setDouble:(double)value forKey:(NSString *)defaultName {
	pthread_mutex_lock(&lock);
	Status status = self.database->Put(writeOptions, NULDBSliceFromObject([NSNumber numberWithDouble:value]), CFISliceFromString(defaultName));
	pthread_mutex_unlock(&lock);
}

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
	pthread_mutex_lock(&lock);
	Status status = self.database->Put(writeOptions, NULDBSliceFromObject([NSNumber numberWithBool:value]), CFISliceFromString(defaultName));
	pthread_mutex_unlock(&lock);
}

- (void)setURL:(NSURL *)url forKey:(NSString *)defaultName {
	pthread_mutex_lock(&lock);
	Status status = self.database->Put(writeOptions, NULDBSliceFromObject(url), CFISliceFromString(defaultName));
	pthread_mutex_unlock(&lock);
}

- (void)removeObjectForKey:(NSString *)defaultName {
	pthread_mutex_lock(&lock);
	Status status = self.database->Delete(writeOptions, CFISliceFromString(defaultName));
	pthread_mutex_unlock(&lock);
}

- (NSArray *)volatileDomainNames {
	return [NSUserDefaults.standardUserDefaults volatileDomainNames];
}

- (NSDictionary *)volatileDomainForName:(NSString *)domainName {
	return [NSUserDefaults.standardUserDefaults volatileDomainForName:domainName];
}

- (void)setVolatileDomain:(NSDictionary *)domain forName:(NSString *)domainName {
	[NSUserDefaults.standardUserDefaults setVolatileDomain:domain forName:domainName];
}

- (void)removeVolatileDomainForName:(NSString *)domainName {
	[NSUserDefaults.standardUserDefaults removeVolatileDomainForName:domainName];
}

- (NSArray *)persistentDomainNames {
	return [NSUserDefaults.standardUserDefaults persistentDomainNames];
}

- (NSDictionary *)persistentDomainForName:(NSString *)domainName {
	return [NSUserDefaults.standardUserDefaults persistentDomainForName:domainName];
}

- (void)setPersistentDomain:(NSDictionary *)domain forName:(NSString *)domainName {
	[NSUserDefaults.standardUserDefaults setPersistentDomain:domain forName:domainName];
}

- (void)removePersistentDomainForName:(NSString *)domainName {
	[NSUserDefaults.standardUserDefaults removePersistentDomainForName:domainName];
}

- (void)addSuiteNamed:(NSString *)suiteName {
	[NSUserDefaults.standardUserDefaults addSuiteNamed:suiteName];
}

- (void)removeSuiteNamed:(NSString *)suiteName {
	[NSUserDefaults.standardUserDefaults removeSuiteNamed:suiteName];
}

- (BOOL)synchronize {
	return NO;
}

- (BOOL)objectIsForcedForKey:(NSString *)key {
	return NO;
}

- (BOOL)objectIsForcedForKey:(NSString *)key inDomain:(NSString *)domain {
	return NO;
}

@end

@implementation PSTUserDefaults (CFISubscripting)

- (id)objectForKeyedSubscript:(NSString*)key {
	return [self objectForKey:key];
}

- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString*)key {
	[self setObject:obj forKey:key];
}

@end
