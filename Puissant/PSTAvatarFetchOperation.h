//
//  PSTAvatarFetchOperation.h
//  Puissant
//
//  Created by Robert Widmann on 4/21/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSTAvatarImageManager.h"

@interface PSTAvatarFetchOperation : NSOperation

+ (instancetype)avatarFetchOperationForEmail:(NSString*)email completion:(void(^)(PSTAvatarFetchOperation *op))completion;

@property (nonatomic, copy) NSString *email;
@property (nonatomic, strong, readonly) NSImage *image;

@end
