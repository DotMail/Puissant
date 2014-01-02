//
//  NSApplication+PSTSystemAdditions.m
//  Puissant
//
//  Created by Robert Widmann on 1/26/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "NSApplication+PSTSystemAdditions.h"
#import <CoreServices/CoreServices.h>

@implementation NSApplication (PSTSystemAdditions)

+(BOOL)dm_runningMountainLionOrLater {
	SInt32 minorVersion;
	Gestalt(gestaltSystemVersionMinor, &minorVersion);
	
	return (minorVersion >= 8);
}

+(BOOL)dm_runningLionOrLater {
	SInt32 minorVersion;
	Gestalt(gestaltSystemVersionMinor, &minorVersion);

	return (minorVersion >= 7);
}

@end
