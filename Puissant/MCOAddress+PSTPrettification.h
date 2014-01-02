//
//  MCOAddress+PSTPrettification.h
//  Puissant
//
//  Created by Robert Widmann on 2/2/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <MailCore/MCOAddress.h>

@interface MCOAddress (PSTPrettification) <NSCoding>

- (NSString*)dm_prettifiedDisplayString;
- (NSString *)prettifiedStringValue;

@end
