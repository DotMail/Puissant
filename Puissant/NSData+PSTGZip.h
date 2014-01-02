//
//  NSData+PSTGZip.h
//  Puissant
//
//  Created by Robert Widmann on 11/25/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (PSTGZip)

- (id)dmUnarchivedData;
- (NSData*)dmArchivedData;

@end
