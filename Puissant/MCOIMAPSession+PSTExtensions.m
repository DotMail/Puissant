//
//  MCOIMAPSession+PSTExtensions.m
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "MCOIMAPSession+PSTExtensions.h"
#import <MailCore/MCOIMAPNamespace.h>
#import <MailCore/MCOIMAPFolder.h>
#import <MailCore/MCOMailProvider.h>
#import <objc/runtime.h>

#define GMAIL_PROVIDER_IDENTIFIER @"gmail"

static char *DOTMAIL_XLIST_MAPPING_KEY;

@implementation MCOIMAPSession (PSTExtensions)

- (void)setupNamespaceWithPrefix:(NSString *)prefix delimiter:(char)delimiter {
	[self setDefaultNamespace:[MCOIMAPNamespace namespaceWithPrefix:prefix delimiter:delimiter]];
}

- (void)setDm_XListMapping:(NSDictionary *)dm_XListMapping {
	objc_setAssociatedObject(self, DOTMAIL_XLIST_MAPPING_KEY, dm_XListMapping, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)dm_XListMapping {
	return objc_getAssociatedObject(self, DOTMAIL_XLIST_MAPPING_KEY);
}

- (MCOIMAPFolder *)inboxFolder {
	return [self folderWithPath:@"INBOX"];
}

- (MCOIMAPFolder *)folderWithPath:(NSString *)path {
	MCOIMAPFolder * folder;
	
	folder = [[MCOIMAPFolder alloc] init];
	[folder setPath:path];
	
	return folder;
}

- (MCOIMAPFolder *)_providerFolderWithPath:(NSString *)path {
	NSString * fullPath;
	
	if ([self defaultNamespace] == nil) {
		fullPath = path;
	}
	else {
		fullPath = [[[self defaultNamespace] mainPrefix] stringByAppendingString:path];
	}
	return [self folderWithPath:fullPath];
}

- (MCOIMAPFolder *)sentMailFolderForProvider:(MCOMailProvider *)provider {
	if (self.dm_XListMapping != nil) {
		if ([self.dm_XListMapping objectForKey:@"sentmail"] != nil) {
			return [self _providerFolderWithPath:[self.dm_XListMapping objectForKey:@"sentmail"]];
		}
	}
	
	if ([provider sentMailFolderPath] == nil)
		return nil;
	
	return [self _providerFolderWithPath:[provider sentMailFolderPath]];
}

- (MCOIMAPFolder *)starredFolderForProvider:(MCOMailProvider *)provider {
	if (self.dm_XListMapping != nil) {
		if ([self.dm_XListMapping objectForKey:@"starred"] != nil) {
			return [self _providerFolderWithPath:[self.dm_XListMapping objectForKey:@"starred"]];
		}
	}
	
	if ([provider starredFolderPath] == nil)
		return nil;
	
	return [self _providerFolderWithPath:[provider starredFolderPath]];
}

- (MCOIMAPFolder *)allMailFolderForProvider:(MCOMailProvider *)provider {
	if (self.dm_XListMapping != nil) {
		if ([self.dm_XListMapping objectForKey:@"allmail"] != nil) {
			return [self _providerFolderWithPath:[self.dm_XListMapping objectForKey:@"allmail"]];
		}
	}
	
	if ([provider allMailFolderPath] == nil)
		return nil;
	
	return [self _providerFolderWithPath:[provider allMailFolderPath]];
}

- (MCOIMAPFolder *)trashFolderForProvider:(MCOMailProvider *)provider {
	if (self.dm_XListMapping != nil) {
		if ([self.dm_XListMapping objectForKey:@"trash"] != nil) {
			return [self _providerFolderWithPath:[self.dm_XListMapping objectForKey:@"trash"]];
		}
	}
	
	if ([provider trashFolderPath] == nil)
		return nil;
	
	return [self _providerFolderWithPath:[provider trashFolderPath]];
}

- (MCOIMAPFolder *)draftsFolderForProvider:(MCOMailProvider *)provider {
	if (self.dm_XListMapping != nil) {
		if ([self.dm_XListMapping objectForKey:@"drafts"] != nil) {
			return [self _providerFolderWithPath:[self.dm_XListMapping objectForKey:@"drafts"]];
		}
	}
	
	if ([provider draftsFolderPath] == nil)
		return nil;
	
	return [self _providerFolderWithPath:[provider draftsFolderPath]];
}

- (MCOIMAPFolder *)spamFolderForProvider:(MCOMailProvider *)provider {
	if (self.dm_XListMapping != nil) {
		if ([self.dm_XListMapping objectForKey:@"spam"] != nil) {
			return [self _providerFolderWithPath:[self.dm_XListMapping objectForKey:@"spam"]];
		}
	}
	
	if ([provider spamFolderPath] == nil)
		return nil;
	
	return [self _providerFolderWithPath:[provider spamFolderPath]];
}

- (MCOIMAPFolder *)importantFolderForProvider:(MCOMailProvider *)provider {
	if (self.dm_XListMapping != nil) {
		if ([self.dm_XListMapping objectForKey:@"important"] != nil) {
			return [self _providerFolderWithPath:[self.dm_XListMapping objectForKey:@"important"]];
		}
	}
	
	if ([provider importantFolderPath] == nil)
		return nil;
	
	return [self _providerFolderWithPath:[provider importantFolderPath]];
}

+ (NSDictionary *)XListMappingWithFolders:(NSArray * /* MCOIMAPFolder */ )folders {
	NSMutableDictionary * result;
	
	result = [NSMutableDictionary dictionary];
	for(MCOIMAPFolder * folder in folders) {
		if (([folder flags] & MCOIMAPFolderFlagInbox) != 0) {
			[result setObject:[folder path] forKey:@"inbox"];
		}
		else if (([folder flags] & MCOIMAPFolderFlagSentMail) != 0) {
			[result setObject:[folder path] forKey:@"sentmail"];
		}
		else if (([folder flags] & MCOIMAPFolderFlagStarred) != 0) {
			[result setObject:[folder path] forKey:@"starred"];
		}
		else if (([folder flags] & MCOIMAPFolderFlagAllMail) != 0) {
			[result setObject:[folder path] forKey:@"allmail"];
		}
		else if (([folder flags] & MCOIMAPFolderFlagTrash) != 0) {
			[result setObject:[folder path] forKey:@"trash"];
		}
		else if (([folder flags] & MCOIMAPFolderFlagDrafts) != 0) {
			[result setObject:[folder path] forKey:@"drafts"];
		}
		else if (([folder flags] & MCOIMAPFolderFlagSpam) != 0) {
			[result setObject:[folder path] forKey:@"spam"];
		}
		else if (([folder flags] & MCOIMAPFolderFlagImportant) != 0) {
			[result setObject:[folder path] forKey:@"important"];
		}
	}
	
	return result;
}

@end
