//
//  NSApplication+PSTSystemAdditions.h
//  Puissant
//
//  Created by Robert Widmann on 1/26/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSApplication (PSTSystemAdditions)

+(BOOL)dm_runningMountainLionOrLater;
+(BOOL)dm_runningLionOrLater;

@end
