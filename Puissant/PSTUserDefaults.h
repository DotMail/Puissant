//
//  CFIUserDefaults.h
//  UserDefaultsPerformanceSuite
//
//  Created by Robert Widmann on 3/24/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTConstants.h"

#ifdef __cplusplus
#include <leveldb/db.h>
#include <leveldb/slice.h>
#include <leveldb/options.h>
#include <leveldb/comparator.h>
#include <leveldb/write_batch.h>
#endif

/*!
 * "This notification is posted when a change is made to defaults in a persistent domain.
 * The notification object is the CFIUserDefaults object. This notification does not contain a
 * userInfo dictionary."
 */
PUISSANT_EXPORT NSString * const PSTUserDefaultsDidChangeNotification;

/*!
 * A Map-on-steroids-like interface to a LevelDB-backed defaults cache.  This class is designed to
 * emulate the features of NSUserDefaults exactly, save a few methods that have little use, or will
 * be implemented in a future version of this defaults object.  The cache is synchronized, so multi-
 * threaded applications can read and write to and from the cache safely.
 *
 * The class is a little more flexible than NSUserDefaults, as any object that conforms to NSCoding
 * is allowed to be registered to the cache of defaults.
 */
@interface PSTUserDefaults : NSObject

/*!
 * Initializes and returns shared User Defaults object.  #define CFIINSANESINGLETONS to use an
 * OSAtomic singleton, rather than the "standard" GCD dispatched one that's been floating around the
 * community for a while.
 */
+ (instancetype)standardUserDefaults;

/*!
 * Destroys, then recreates the defaults database and cache.  It is not necessary to call
 * -registerDefaults: after a call to reset, as registered defaults are not affected by the purge.
 */
+ (void)resetStandardUserDefaults;

/*!
 * Destroys and closes the defaults database and prepares for destruction itself.  This should be
 * called near the end of the application's lifecycle.
 */
- (void)flushClosed;

/*!
 * Don't call this.  I don't even know why it's exposed in the NSUserDefaults class in the first
 * place.  Just seriously, don't touch it.  Back away slowly...
 */
- (id)init;

/*!
 * Looks up, and returns, a value in the database.  Values are returned Raw and Immutable.
 * Basically, all subsequent getters for objects are just this, plus a little casting or
 * de-archiving magic to get a value from the store or the registered defaults.  Returns nil on
 * a failure to get an object from either the store or the registered defaults dictionary.
 *
 * This method is more type-safe than the one defined by NSUserDefaults, as objects are required to
 * conform to NSCoding.  Failure to conform will result in a fatal NSCoding exception.
 */
- (id<NSCoding>)objectForKey:(NSString *)defaultName;

/*!
 * Puts the specified value in the database.  Values must conform to NSCoding.  Failure to conform
 * results in a fatal NSCoding exception.
 */
- (void)setObject:(id<NSCoding>)value forKey:(NSString *)defaultName;

/*!
 * Removes the given key-value pair from the database.
 */
- (void)removeObjectForKey:(NSString *)defaultName;

/*!
 * If the given value from a call to -objectForKey: is some kind of NSString, then return it, else
 * return nil.
 */
- (NSString *)stringForKey:(NSString *)defaultName;

/*!
 * If the given value from a call to -objectForKey: is some kind of NSArray, then return it, else
 * return nil.
 */
- (NSArray *)arrayForKey:(NSString *)defaultName;

/*!
 * If the given value from a call to -objectForKey: is some kind of NSDictionary, then return it,
 * else return nil.
 */
- (NSDictionary *)dictionaryForKey:(NSString *)defaultName;

/*!
 * If the given value from a call to -objectForKey: is some kind of NSData, then return it,
 * else return nil.
 */
- (NSData *)dataForKey:(NSString *)defaultName;

/*!
 * Not quite sure how this differs from the whole -arrayForKey: thing, but it's here!
 */
- (NSArray *)stringArrayForKey:(NSString *)defaultName;

/*!
 * If the given value from a call to -objectForKey: is some kind of NSNumber or NSString, then return
 * it's -integerValue, else return 0.
 */
- (NSInteger)integerForKey:(NSString *)defaultName;

/*!
 * If the given value from a call to -objectForKey: is some kind of NSNumber or NSString, then return
 * it's -floatValue, else return 0.
 */
- (float)floatForKey:(NSString *)defaultName;

/*!
 * If the given value from a call to -objectForKey: is some kind of NSNumber or NSString, then return
 * it's -doubleValue, else return 0.
 */
- (double)doubleForKey:(NSString *)defaultName;

/*!
 * If the given value from a call to -objectForKey: is some kind of NSNumber, then return it's
 * -boolValue, else return 0.  If the return value is a string, then it is compared against the
 * values @"YES" and @"NO".  Ain't that cool?
 */
- (BOOL)boolForKey:(NSString *)defaultName;

/*!
 * If the given value from a call to -objectForKey: is some kind of NSURL, return it.  If it is some
 * kind of NSString, then return a URL composed of its contents, else return nil.
 */
- (NSURL *)URLForKey:(NSString *)defaultName;

/*!
 * Wraps the given value in an NSNumber and stores it in the database.
 */
- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;

/*!
 * Wraps the given value in an NSNumber and stores it in the database.
 */
- (void)setFloat:(float)value forKey:(NSString *)defaultName;

/*!
 * Wraps the given value in an NSNumber and stores it in the database.
 */
- (void)setDouble:(double)value forKey:(NSString *)defaultName;

/*!
 * Wraps the given value in an NSNumber and stores it in the database.
 */
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;

/*!
 * Stores the URL in the database.  I have no idea why this is here, as calling -setObject:forKey:
 * works just fine for NSURL, as it conforms to NSCoding.
 */
- (void)setURL:(NSURL *)url forKey:(NSString *)defaultName;

/*!
 * Registers a dictionary of default values that are used should the cache be cleared, removed,
 * corrupted, etc. in some way.  A call to -registerDefaults: should be made once at every launch
 * of the application, as the main cache could (but really won't) be removed at any time.
 * The preferred place to call -registerDefaults: is in +initialize of the AppDelegate so it is set
 * before any defaults are used.
 */
- (void)registerDefaults:(NSDictionary *)registrationDictionary;

/*!
 * A dictionary containing the keys. The keys are names of defaults and the value corresponding to
 * each key is an encoding-capable object.
 */
- (NSDictionary *)dictionaryRepresentation;

@end

/*!
 * Subscripting, because why not?
 */
#if __has_feature(objc_subscripting)
@interface PSTUserDefaults (CFISubscripting)

- (id)objectForKeyedSubscript:(NSString*)key;
- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString*)key;

@end
#endif


/*!
 * The following methods are either deprecated or unimplemented.  Their implementations default to
 * either an error value (usually 0, nil, NULL, etc.), or to whatever NSUserDefaults happens to do.
 * Note: -synchronize is deprecated permanently as LevelDB handles synchronization and cache
 * flushing for us.
 */
@interface PSTUserDefaults (CFIDeprecated)
- (id)initWithUser:(NSString *)username DEPRECATED_ATTRIBUTE;

- (void)addSuiteNamed:(NSString *)suiteName;
- (void)removeSuiteNamed:(NSString *)suiteName;

- (NSArray *)volatileDomainNames;
- (NSDictionary *)volatileDomainForName:(NSString *)domainName;
- (void)setVolatileDomain:(NSDictionary *)domain forName:(NSString *)domainName;
- (void)removeVolatileDomainForName:(NSString *)domainName;

- (NSArray *)persistentDomainNames;
- (NSDictionary *)persistentDomainForName:(NSString *)domainName;
- (void)setPersistentDomain:(NSDictionary *)domain forName:(NSString *)domainName;
- (void)removePersistentDomainForName:(NSString *)domainName;

- (BOOL)synchronize __attribute__((deprecated("The process of synchronization has been automated")));

- (BOOL)objectIsForcedForKey:(NSString *)key __attribute__((deprecated("Application administrator rights to preferences should be application-determined")));
- (BOOL)objectIsForcedForKey:(NSString *)key inDomain:(NSString *)domain __attribute__((deprecated("Application administrator rights to preferences should be application-determined")));

@end
