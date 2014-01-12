//
//  PSTConstants.c
//  Puissant
//
//  Created by Robert Widmann on 2/10/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "PSTConstants.h"
#import <MailCore/MCOIMAPMessage.h>
#import <MailCore/MCOIMAPFolder.h>
#import "PSTSerializablePart.h"
#import <libgen.h>
#import <time.h>
#import <sys/time.h>
#include <execinfo.h>
#include <pthread.h>

NSTimeInterval const PSTDefaultRefreshTimeInterval = 120;

NSUInteger const kPSTAutoresizingMaskAll = (NSViewWidthSizable | NSViewHeightSizable |
										   NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin |
										   NSViewMaxYMargin);

NSString *const PSTMainWindowAutosavedFullscreenStateKey = @"PSTMainWindowAutosavedFullscreenStateKey";
NSString *const PSTMainWindowAutosavedFrameKey = @"PSTMainWindowAutosavedFrameKey";
NSString *const PSTStorageReadyNotification = @"PSTStorageReadyNotification";
NSString *const PSTStorageGotModifiedConversationNotification = @"PSTIMAPAsyncStorageGotModifiedConversationNotification";
NSString *const PSTErrorDomain = @"DotMailGenericErrorDomain";
NSString *const PSTAccountManagerChangedNotification = @"PSTAccountManagerChanged";
NSString *const PSTAccountManagerAccountListChangedNotification = @"PSTAccountManagerAccountListChanged";
NSString *const PSTAccountManagerShouldRefreshOtherAccountsNotification = @"PSTAccountManagerShouldRefreshOtherAccounts";
NSString *const PSTAccountControllerManagerAccountListChangedNotification = @"PSTAccountControllerManagerAccountListChanged";
NSString *const PSTMailAccountFetchedMessageNotification = @"PSTMailAccountFetchedMessage";
NSString *const PSTMailAccountFetchedNewMessageNotification = @"PSTMailAccountFetchedNewMessageNotification";
NSString *const PSTMailAccountDraftSavedNotification = @"PSTMailAccountDraftSaved";
NSString *const PSTMailAccountLocalDraftSavedNotification  = @"PSTMailAccountLocalDraftSavedNotification";
NSString *const PSTMailAccountLabelColorsUpdatedNotification  = @"PSTMailAccountLabelColorsUpdatedNotification";
NSString *const PSTMailAccountNotificationChanged = @"PSTMailAccountNotificationChanged";
NSString *const PSTMailAccountCountUpdated = @"PSTMailAccountCountUpdated";
NSString *const PSTMailAccountActionStepCountUpdated = @"PSTMailAccountActionStepCountUpdated";
NSString *const PSTMailAccountLabelsColorsChanged = @"PSTMailAccountLabelsColorsChanged";
NSString *const PSTMailAccountSynchronizerModifiedConversations = @"PSTMailAccountSynchronizerModifiedConversations";
NSString *const PSTMailAccountMessageDidSendMessageNotification = @"PSTMailAccountMessageDidSendMessage";
NSString *const PSTMailAccountConversationForMessageIDFetched = @"PSTMailAccountConversationForMessageIDFetched";
NSString *const PSTMailAccountLabelOperationSucceeded = @"PSTMailAccountLabelOperationSucceeded";
NSString *const PSTAccountKey = @"PSTAccountKey";
NSString *const PSTErrorKey = @"PSTErrorKey";
NSString *const PSTLabelOperationKey = @"PSTLabelOperationKey";
NSString *const PSTLabelNameKey = @"PSTLabelNameKey";
NSString *const PSTAccountKindKey = @"PSTAccountKindKey";
NSString *const PSTAttachmentKey = @"PSTAttachmentKey";
NSString *const PSTSenderKey = @"PSTSenderKey";
NSString *const PSTTitleKey = @"PSTTitleKey";
NSString *const PSTPreviewKey = @"PSTPreviewKey";
NSString *const PSTAccountNewLabelNameKey = @"PSTAccountNewLabelNameKey";
NSString *const PSTMessageKey = @"PSTMessageKey";
NSString *const PSTMessagesKey = @"PSTMessagesKey"; //multiple messages
NSString *const PSTConversationIDKey = @"PSTConversationIDKey";
NSString *const PSTConversationIDsKey = @"PSTConversationIDsKey"; //multiple conversations
NSString *const PSTNotificationMessageKey = @"PSTNotificationMessageKey";
NSString *const PSTMailUnifiedAccountCountUpdated = @"PSTMailUnifiedAccountCountUpdated";
NSString *const PSTAccountControllerLabelsColorsChanged = @"PSTAccountControllerLabelsColorsChanged";
NSString *const PSTActivityManagerDidUpdateNotification = @"PSTActivityManagerDidUpdateNotification";
NSString *const PSTWindowWillEnterFullScreenNotification = @"PSTWindowWillEnterFullScreenNotification";
NSString *const PSTWindowDidEnterFullScreenNotification = @"PSTWindowDidEnterFullScreenNotification";
NSString *const PSTWindowWillExitFullScreenNotification = @"PSTWindowWillExitFullScreenNotification";
NSString *const PSTWindowDidExitFullScreenNotification = @"PSTWindowDidExitFullScreenNotification";
NSString *const PSTSidebarOldSizeConstant = @"PSTSidebarOldSizeConstant"; /*NSString (NSRect)*/
NSString *const PSTSidebarEnabled = @"PSTSidebarEnabled"; /*BOOL*/
NSString *const PSTUnifiedInboxEnabled = @"PSTUnifiedInboxEnabled"; /*BOOL*/
NSString *const PSTMailAccountDidFinishSyncingAllFoldersNotification = @"PSTMailAccountDidFinishSyncingAllFoldersNotification";
NSString *const PSTAvatarImageManagerDidUpdateNotification = @"PSTAvatarImageManagerDidUpdateNotification";

uint64_t PSTAccumulateDirectorySize(NSArray *inArray) {
	uint64_t accumulator = 0;
	NSString *fileString = nil;
	for (id file in inArray) {
		if ([file isKindOfClass:NSString.class]) {
			fileString = file;
		} else if ([file isKindOfClass:NSURL.class]) {
			fileString = [file path];
		}
		NSDictionary *fileAttributes = [NSFileManager.defaultManager attributesOfItemAtPath:fileString error:nil];
		BOOL fileIsDirectory = [fileAttributes.fileType isEqualToString:NSFileTypeDirectory];
		BOOL fileIsSymbolicLink = [fileAttributes.fileType isEqualToString:NSFileTypeSymbolicLink];
		if (fileIsDirectory) {
			NSMutableArray *allFiles = @[].mutableCopy;
			for (NSString *directoryFile in [NSFileManager.defaultManager contentsOfDirectoryAtPath:fileString error:nil]) {
				[allFiles addObject:[fileString stringByAppendingPathComponent:directoryFile]];
			}
			accumulator += PSTAccumulateDirectorySize(allFiles);
		} else if (fileIsSymbolicLink) {
			NSString *traversedPath = [NSFileManager.defaultManager destinationOfSymbolicLinkAtPath:fileString error:nil];
			NSDictionary *traversedFileAttributes = [NSFileManager.defaultManager attributesOfItemAtPath:traversedPath error:nil];
			accumulator += traversedFileAttributes.fileSize;
		} else {
			accumulator += fileAttributes.fileSize;
		}
	}
	return accumulator;
}

NSArray *PSTArrayMap(NSArray *inArray, id(^PSTArrayMapBlock)(id item)) {
	NSMutableArray *accumulator = @[].mutableCopy;
	for (id object in inArray) {
		[accumulator addObject:PSTArrayMapBlock(object)];
	}
	return accumulator;
}

void PSTArrayDivide(NSArray **slices, NSArray *inArray, NSUInteger parts) {
	if (parts == 0 || parts == 1) {
		*slices = @[ inArray ];
		return;
	}
	NSMutableArray *arrays = [NSMutableArray arrayWithCapacity:parts];
	for (int i = 0; i < parts; i++) {
		arrays[i] = @[].mutableCopy;
	}
	long int idx = 0;
	for (id object in inArray) {
		[arrays[idx] addObject:object];
		idx = (idx + 1) % parts;
	}
	*slices = arrays;
}

void PSTPreferentialArrayDivide(NSArray **slices, NSArray *inArray, NSUInteger parts) {
	if (parts == 0 || parts == 1) {
		*slices = @[ inArray ];
		return;
	}
	NSMutableArray *arrays = [NSMutableArray arrayWithCapacity:parts];
	for (int i = 0; i < parts; i++) {
		arrays[i] = @[].mutableCopy;
	}
	long int idx = 0;
	for (id object in inArray) {
		[arrays[idx] addObject:object];
		idx = (idx + 1) % parts;
	}
	
	int counter = 0, preferredIndex = -1;
	for (NSMutableArray *array in arrays) {
		if ([[array[0] path]isEqualToString:@"INBOX"]) {
			preferredIndex = counter;
			break;
		}
		counter++;
	}
	if (preferredIndex != -1) {
		NSMutableArray *preferredArray = [arrays objectAtIndex:preferredIndex];
		[arrays removeObjectAtIndex:preferredIndex];
		[arrays insertObject:preferredArray atIndex:0];
	}
	*slices = arrays;
}

extern void PSTReverseArrayDivide(NSArray **slices, NSArray *inArray, NSUInteger parts) {
	if (parts == 0 || parts == 1) {
		*slices = @[ inArray ];
		return;
	}
	NSMutableArray *arrays = [NSMutableArray arrayWithCapacity:parts];
	for (int i = 0; i < parts; i++) {
		arrays[i] = @[].mutableCopy;
	}
	long int idx = 0;
	for (id object in inArray.reverseObjectEnumerator) {
		[arrays[idx] addObject:object];
		idx = (idx + 1) % parts;
	}
	*slices = arrays;
}

void PSTIndexSetDivide(NSArray **slices, NSIndexSet *inIndexSet, NSUInteger parts) {
	if (parts == 0 || parts == 1) {
		*slices = [NSArray arrayWithObject:inIndexSet];
		return;
	}
	NSMutableArray *indexSets = [NSMutableArray arrayWithCapacity:parts];
	for (int i = 0; i < parts; i++) {
		indexSets[i] = [NSMutableIndexSet indexSet];
	}
	
	NSUInteger divisor = roundtol(inIndexSet.count / parts);
	__block NSUInteger idx = 0;
	__block NSUInteger indexSetIdx = 0;
	__block NSMutableIndexSet *currentIndexSet = nil;
	[inIndexSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		if (idx % divisor == 0) {
			currentIndexSet = indexSets[indexSetIdx];
			if (indexSetIdx + 1 < indexSets.count)
				indexSetIdx++;
		}
		[currentIndexSet addIndex:index];
		idx++;
	}];
	
	*slices = indexSets;
}

void PSTReverseIndexSetDivide(NSArray **slices, NSIndexSet *inIndexSet, NSUInteger parts) {
	if (parts == 0 || parts == 1) {
		*slices = [NSArray arrayWithObject:inIndexSet];
		return;
	}
	NSMutableArray *indexSets = [NSMutableArray arrayWithCapacity:parts];
	for (int i = 0; i < parts; i++) {
		indexSets[i] = [NSMutableIndexSet indexSet];
	}
	
	NSUInteger divisor = roundtol(inIndexSet.count / parts);
	__block NSUInteger idx = 0;
	__block NSUInteger indexSetIdx = 0;
	__block NSMutableIndexSet *currentIndexSet = nil;
	[inIndexSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		if (idx % divisor == 0) {
			currentIndexSet = indexSets[indexSetIdx];
			if (indexSetIdx + 1 < indexSets.count)
				indexSetIdx++;
		}
		[currentIndexSet addIndex:index];
		idx++;
	}];
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[indexSets count]];
    NSEnumerator *enumerator = [indexSets reverseObjectEnumerator];
    for (id element in enumerator) {
        [array addObject:element];
    }
	*slices = array;
}

NSIndexSet *PSTIMAPMessageArrayToIndexSet(NSArray *array) {
	NSMutableIndexSet *retVal = [[NSMutableIndexSet alloc]init];
	
	for (MCOIMAPMessage *msg in array) {
		[retVal addIndex:msg.uid];
	}
	
	return retVal;
}

NSIndexSet *PSTIndexSetOfNumbers(NSArray *uids) {
	NSMutableIndexSet *result = [[NSMutableIndexSet alloc]init];
	for (NSNumber *number in uids) {
		[result addIndex:[number unsignedLongValue]];
	}
	return result;
}

MCOAbstractPart *PSTPreferredIMAPPart(NSArray *parts) {
	int htmlPart = -1;
	int textPart = -1;
	int largerSizeIndex = -1;
	NSInteger largerSize = -1;
	
	for(unsigned int i = 0 ; i < parts.count ; i ++) {
		PSTSerializablePart * subpart = (PSTSerializablePart *)parts[i];
		if ([subpart.mimeType.lowercaseString isEqualToString:@"text/html"]) {
			htmlPart = i;
		}
		else if ([subpart.mimeType.lowercaseString isEqualToString:@"text/plain"]) {
			textPart = i;
		}
		if (subpart.size > largerSize) {
			largerSizeIndex = i;
			largerSize = subpart.size;
		}
	}
	if (htmlPart != -1) {
		return (MCOAbstractPart *)[parts objectAtIndex:htmlPart];
	}
	else if (textPart != -1) {
		return (MCOAbstractPart *)[parts objectAtIndex:textPart];
	}
	else if (parts.count > 0) {
		return (MCOAbstractPart *)[parts objectAtIndex:0];
	}
	else {
		return nil;
	}
}

static NSSet * enabledFilesSet = nil;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

void LEPLogInternal(const char * filename, unsigned int line, int dumpStack, NSString * format, ...)
{
	va_list argp;
	NSString * str;
	char * filenameCopy;
	char * lastPathComponent;
	struct timeval tv;
	struct tm tm_value;
	//NSDictionary * enabledFilenames;
	
	@autoreleasepool {
		pthread_mutex_lock(&lock);
		if (enabledFilesSet == nil) {
			enabledFilesSet = [[NSSet alloc] initWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:PSTLogEnabledFilenames]];
		}
		pthread_mutex_unlock(&lock);
		
		NSString * fn;
		fn = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:filename length:strlen(filename)];
		fn = [fn lastPathComponent];
		if (![enabledFilesSet containsObject:fn]) {
			return;
		}
		
		va_start(argp, format);
		str = [[NSString alloc] initWithFormat:format arguments:argp];
		va_end(argp);
		
		NSString * outputFileName = [[NSUserDefaults standardUserDefaults] stringForKey:PSTLogOutputFilename];
		static FILE * outputfileStream = NULL;
		if ( ( NULL == outputfileStream ) && outputFileName )
		{
			outputfileStream = fopen( [outputFileName UTF8String], "w+" );
		}
		
		if ( NULL == outputfileStream )
			outputfileStream = stderr;
		
		gettimeofday(&tv, NULL);
		localtime_r(&tv.tv_sec, &tm_value);
		fprintf(outputfileStream, "%04u-%02u-%02u %02u:%02u:%02u.%03u ", tm_value.tm_year + 1900, tm_value.tm_mon + 1, tm_value.tm_mday, tm_value.tm_hour, tm_value.tm_min, tm_value.tm_sec, tv.tv_usec / 1000);
		//fprintf(stderr, "%10s ", [[[NSDate date] description] UTF8String]);
		fprintf(outputfileStream, "[%s:%u] ", [[[NSProcessInfo processInfo] processName] UTF8String], [[NSProcessInfo processInfo] processIdentifier]);
		filenameCopy = strdup(filename);
		lastPathComponent = basename(filenameCopy);
		fprintf(outputfileStream, "(%s:%u) ", lastPathComponent, line);
		free(filenameCopy);
		fprintf(outputfileStream, "%s\n", [str UTF8String]);
		
		if (dumpStack) {
			void * frame[128];
			int frameCount;
			int i;
			
			frameCount = backtrace(frame, 128);
			for(i = 0 ; i < frameCount ; i ++) {
				fprintf(outputfileStream, "  %p\n", frame[i]);
			}
		}
		
		if ( outputFileName )
		{
			fflush(outputfileStream);
		}
	}
	
}