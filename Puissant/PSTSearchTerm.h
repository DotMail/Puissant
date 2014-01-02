//
//  PSTSearchTerm.h
//  Puissant
//
//  Created by Robert Widmann on 11/12/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

@interface PSTSearchTerm : NSTextAttachment

@property (nonatomic) int kind;
@property (nonatomic, strong) id value;
@property (nonatomic, strong) NSAttributedString *originalString;
@property (nonatomic, strong) NSDate *date;

@end
