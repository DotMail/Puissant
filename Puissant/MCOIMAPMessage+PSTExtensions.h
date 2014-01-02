//
//  MCOIMAPMessage+PSTExtensions.h
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <MailCore/MCOIMAPMessage.h>

@class MCOIMAPFolder;

@interface MCOAbstractMessage (PSTExtensions)

- (void)dm_setFolder:(MCOIMAPFolder *)folder;
- (MCOIMAPFolder *)dm_folder;

@end
