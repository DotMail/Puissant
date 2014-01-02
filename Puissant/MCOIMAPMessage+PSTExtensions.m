//
//  MCOIMAPMessage+PSTExtensions.m
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "MCOIMAPMessage+PSTExtensions.h"
#include <objc/runtime.h>

static char PST_FOLDER_KEY;

@implementation MCOAbstractMessage (PSTExtensions)

- (void)dm_setFolder:(MCOIMAPFolder *)folder {
	objc_setAssociatedObject(self, PST_FOLDER_KEY, folder, OBJC_ASSOCIATION_RETAIN);
}

- (MCOIMAPFolder *)dm_folder {
	return objc_getAssociatedObject(self, PST_FOLDER_KEY);
}

@end
