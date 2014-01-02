//
//  PSTDefines.h
//  Puissant
//
//  Created by IDA WIPSTANN on 1/1/14.
//  Copyright (c) 2014 CodaFi. All rights reserved.
//

#ifndef Puissant_PSTDefines_h
#define Puissant_PSTDefines_h

#if defined(__cplusplus)
#define PUISSANT_EXTERN extern "C"
#else
#define PUISSANT_EXTERN extern
#endif

#define PUISSANT_EXPORT PUISSANT_EXTERN

#ifdef DEBUG
#define PSTLog(...) LEPLogInternal(__FILE__, __LINE__, 0, __VA_ARGS__)
#else
#define PSTLog(...)
#endif

#define PSTLogEnabledFilenames @"PSTLogEnabledFilenames"
#define PSTLogOutputFilename @"PSTLogOutputFilename"

#define PSTPropogateValueForKey(keypath, BLOCK) [self willChangeValueForKey:[NSString stringWithUTF8String:(((void)(NO && ((void)keypath, NO)), strchr(# keypath, '.') + 1))]]; \
BLOCK \
[self didChangeValueForKey:[NSString stringWithUTF8String:(((void)(NO && ((void)keypath, NO)), strchr(# keypath, '.') + 1))]];

#define GENERATE_PRAGMA(x) _Pragma(#x)
#define PUISSANT_TODO(x) GENERATE_PRAGMA(message("[TODO] " #x))

#ifdef CFI_EXPERIMENTAL_ATOMIC_SINGLETONS
#define PUISSANT_SINGLETON_DECL(CLASS) \
while (!sharedInstance) { \
id temp = [super allocWithZone:NSDefaultMallocZone()]; \
if(OSAtomicCompareAndSwapPtrBarrier(0x0, (__bridge void *)temp, &sharedInstance)) { \
[(__bridge CLASS *)sharedInstance init]; \
} \
else { \
temp = nil; \
} \
} \
return (__bridge CLASS *)(sharedInstance);
#else
#define PUISSANT_SINGLETON_DECL(CLASS) \
static CLASS *sharedInstance; \
static dispatch_once_t onceToken; \
dispatch_once(&onceToken, ^{ \
sharedInstance = [[CLASS alloc] init]; \
}); \
return sharedInstance;
#endif


#endif
