//
//  PSTIMAPMailAccount.h
//  Puissant
//
//  Created by Robert Widmann on 5/14/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Puissant/PSTMailAccount.h>
#import "PSTIMAPAccountSynchronizer.h"

@interface PSTIMAPMailAccount : PSTMailAccount <PSTIMAPAccountSynchronizerDelegate>

@end
