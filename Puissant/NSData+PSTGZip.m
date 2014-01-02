//
//  NSData+PSTGZip.m
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "NSData+PSTGZip.h"

@implementation NSData (PSTGZip)

- (id)dmUnarchivedData {
	return [NSKeyedUnarchiver unarchiveObjectWithData:self];
}

- (NSData*)dmArchivedData {
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}

@end
