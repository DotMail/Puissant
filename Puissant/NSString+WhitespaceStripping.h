//
//  NSString+WhitespaceStripping.h
//  Puissant
//
//  Created by Robert Widmann on 2/2/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (WhitespaceStripping)

- (NSString*)stringByTrimmingLeadingWhitespace;
- (NSString*)stringByTrimmingTailingWhitespace;
- (NSString*)stringByTrimmingLeadingAndTailingWhitespace;

@end
