//
//  PSTAvatarImageManager.h
//  Puissant
//
//  Created by Robert Widmann on 4/12/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(int, PSTImageServiceType) {
	PSTImageServiceTypeImageCache = -2,
	PSTImageServiceTypeAddressBook = -1,
	PSTImageServiceTypeGravatar = 0,
	PSTImageServiceTypeGmail,
	PSTImageServiceTypeFacebook,
	PSTImageServiceTypeCount, /* Do not use! */
};

/**
 * This class maintains a transient dictionary of avatar image objects and a 
 * mapping between them and an account.  The avatar manager also automatically
 * fetches and caches any previously uncached or unknown image values and can
 * make requests to a battery of services to retrieve a suitable avatar
 * automatically.
 */
@interface PSTAvatarImageManager : NSObject

/*!
 * Returns an initialized Avatar Image Manager object.
 */
+ (instancetype)defaultManager;

/**
 * Returns an image corresponding to an entry in the images cache for a given 
 * email.  If no image is found in either the primary cache or on disk, then a 
 * request is sent first to the address book, then to gravatar, then to 
 * Facebook, and cached in the primary cache.  If no image is found after
 * the operation completes, then the default image will be returned.
 */
- (NSImage *)avatarForEmail:(NSString *)email;

/**
 * Flushes the primary image cache to disk and cleans up the secondary cache.
 */
- (oneway void)close;

@end
