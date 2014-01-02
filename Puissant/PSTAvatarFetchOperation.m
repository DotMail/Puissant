//
//  PSTAvatarFetchOperation.m
//  Puissant
//
//  Created by Robert Widmann on 4/21/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTAvatarFetchOperation.h"
#import "PSTAddressBookManager.h"
#import "PSTImageMapTable.h"
#import <CommonCrypto/CommonDigest.h>

@interface PSTAvatarFetchOperation ()

@property (nonatomic, strong) NSImage *image;
@property (nonatomic, copy) void(^avatarFetchBlock)(PSTAvatarFetchOperation *op);

@end

@implementation PSTAvatarFetchOperation

+ (instancetype)avatarFetchOperationForEmail:(NSString*)email completion:(void(^)(PSTAvatarFetchOperation *op))completion {
	return [[self alloc]initWithEmail:email completion:completion];
}

- (instancetype)initWithEmail:(NSString*)email completion:(void(^)(PSTAvatarFetchOperation *op))comp {
	self = [super init];
	
	_email = email;
	_avatarFetchBlock = comp;
	
	return self;
}

- (void)main {
	[self loopFetchWithService:PSTImageServiceTypeImageCache];
}

- (void)loopFetchWithService:(PSTImageServiceType)type {
	if (self.isCancelled) {
		[self performSelectorOnMainThread:@selector(_finished) withObject:nil waitUntilDone:YES];
		return;
	}
	switch (type) {
		case PSTImageServiceTypeImageCache:
			_image = [PSTImageMapTable.defaultMapTable imageForEmail:self.email];
			if (_image) {
				[self performSelectorOnMainThread:@selector(_finished) withObject:nil waitUntilDone:YES];
				return;
			}
			break;
		case PSTImageServiceTypeAddressBook:
			_image = [[NSImage alloc]initWithData:[PSTAddressBookManager.sharedManager personForEmail:self.email].imageData];
			if (_image) {
				[PSTImageMapTable.defaultMapTable setImage:_image forEmail:self.email];
				[self performSelectorOnMainThread:@selector(_finished) withObject:nil waitUntilDone:YES];
				return;
			}
			break;
		case PSTImageServiceTypeGravatar:
			_image = [[NSImage alloc]initWithData:self.requestGravatar];
			if (_image) {
				[PSTImageMapTable.defaultMapTable setImage:_image forEmail:self.email];
				[self performSelectorOnMainThread:@selector(_finished) withObject:nil waitUntilDone:YES];
				return;
			}
			break;
		default:
			[self performSelectorOnMainThread:@selector(_finished) withObject:nil waitUntilDone:YES];
			return;
			break;
	}
	[self loopFetchWithService:(++type)];
}

- (void)_finished {
	self.avatarFetchBlock(self);
}

- (NSData *)requestGravatar {
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:PSTGravatarURLForEmail(self.email)];
	urlRequest.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
	NSError *error = nil;
	NSURLResponse *response = nil;

	NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	
	
	return data;
}

static NSURL *PSTGravatarURLForEmail(NSString *email) {
	NSString *curatedEmail = [email stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].lowercaseString;
	
	const char *cStr = [curatedEmail UTF8String];
	unsigned char result[16];
	CC_MD5(cStr, (CC_LONG)strlen(cStr), result); // compute MD5
	
	NSString *md5email = [NSString stringWithFormat:
						  @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
						  result[0], result[1], result[2], result[3],
						  result[4], result[5], result[6], result[7],
						  result[8], result[9], result[10], result[11],
						  result[12], result[13], result[14], result[15]
						  ];
	NSString *gravatarEndPoint = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%@?s=512", md5email];
	
	return [NSURL URLWithString:gravatarEndPoint];
}

@end
