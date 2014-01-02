//
//  NSIndexSet+PSTOperators.h
//  Puissant
//
//  Created by Robert Widmann on 5/25/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSIndexSet (PSTOperators)

- (NSArray *)map:(id(^)(NSUInteger index))mapBlock;

@end
