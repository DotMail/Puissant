//
//  PSTArchiver.h
//  Puissant
//
//  Created by Robert Widmann on 12/1/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PSTArchiver : NSCoder

+ (NSData *)archivedObject:(id)object;
+ (NSData *)archivedObject:(id)object length:(NSUInteger)length;

- (id)initWithData:(NSMutableData*)newData;

@property (nonatomic, strong) NSMutableData *data;

@end

@interface PSTUnarchiver : NSCoder

+ (id)unarchivedObject:(NSData*)dataToDearchive;
- (id)initWithData:(NSData*)newData;

@end
