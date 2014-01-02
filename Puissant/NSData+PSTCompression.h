//
//  NSData+PSTCompression.h
//  Puissant
//
//  Created by Robert Widmann on 12/8/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (PSTCompression)

+(NSData*)dmArchivedData:(id)object;
- (id)dmUnArchivedData:(NSData*)object;

- (id)dataByStandardArchiving;
- (id)dataByStandardUnarchiving;

- (NSData*)dataByGZipInflation;
- (NSData*)dataByGzipDeflation;

@end
