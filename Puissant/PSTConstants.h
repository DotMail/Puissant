//
//  PSTConstants.h
//  DotMail
//
//  Created by Robert Widmann on 9/2/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#ifndef Mail_PSTConstants_h
#define Mail_PSTConstants_h

#include "PSTDefines.h"

@class MCOAbstractPart;

PUISSANT_EXPORT NSTimeInterval const PSTDefaultRefreshTimeInterval;

PUISSANT_EXPORT NSString *const PSTMainWindowAutosavedFullscreenStateKey;
PUISSANT_EXPORT NSString *const PSTMainWindowAutosavedFrameKey;

/**
 * Sent when conversations are found in the storage with some form of modification
 */
PUISSANT_EXPORT NSString *const PSTStorageGotModifiedConversationNotification;

/*
 * Notification of a change to PSTMailAccount's general message state.
 */
PUISSANT_EXPORT NSString *const PSTMailAccountFetchedMessageNotification;
PUISSANT_EXPORT NSString *const PSTMailAccountFetchedNewMessageNotification;
PUISSANT_EXPORT NSString *const PSTMailAccountDraftSavedNotification;
PUISSANT_EXPORT NSString *const PSTMailAccountLocalDraftSavedNotification;
PUISSANT_EXPORT NSString *const PSTMailAccountLabelColorsUpdatedNotification;

//Keys to userInfo
PUISSANT_EXPORT NSString *const PSTAccountKey;
PUISSANT_EXPORT NSString *const PSTErrorKey;
PUISSANT_EXPORT NSString *const PSTLabelOperationKey;
PUISSANT_EXPORT NSString *const PSTLabelNameKey;
PUISSANT_EXPORT NSString *const PSTAccountKindKey;
PUISSANT_EXPORT NSString *const PSTAttachmentKey;
PUISSANT_EXPORT NSString *const PSTSenderKey;
PUISSANT_EXPORT NSString *const PSTTitleKey;
PUISSANT_EXPORT NSString *const PSTPreviewKey;
PUISSANT_EXPORT NSString *const PSTAccountNewLabelNameKey;
PUISSANT_EXPORT NSString *const PSTMessageKey;
PUISSANT_EXPORT NSString *const PSTMessagesKey; //multiple messages
PUISSANT_EXPORT NSString *const PSTConversationIDKey;
PUISSANT_EXPORT NSString *const PSTConversationIDsKey; //multiple conversations
PUISSANT_EXPORT NSString *const PSTNotificationMessageKey;

/*
 Notification of a change to PSTMailUnifiedAccount's general message state.  These are usually triggered
 by changes to the owned PSTMailAccount.
 */
PUISSANT_EXPORT NSString *const PSTMailUnifiedAccountCountUpdated;
PUISSANT_EXPORT NSString *const PSTAccountControllerLabelsColorsChanged;

PUISSANT_EXPORT NSString *const PSTMailAccountDidFinishSyncingAllFoldersNotification;

/*
 Notification of a change in the activity manager.  Will be reflected in the activities popover;
 */
PUISSANT_EXPORT NSString *const PSTActivityManagerDidUpdateNotification;

/*
 Sent by PSTWindow to broadcast the NSWindow delegate methods.  Important for later usage of options that cannot 
 be shown in either fullscreen or normal mode.
 */
PUISSANT_EXPORT NSString *const PSTWindowWillEnterFullScreenNotification;
PUISSANT_EXPORT NSString *const PSTWindowDidEnterFullScreenNotification;
PUISSANT_EXPORT NSString *const PSTWindowWillExitFullScreenNotification;
PUISSANT_EXPORT NSString *const PSTWindowDidExitFullScreenNotification;

/*
 The keypath that is associated with the size of the sidebar before it has been collapsed.  
 Can be unarchived and used to set up the UI.
 */
PUISSANT_EXPORT NSString *const PSTSidebarOldSizeConstant; /*NSString (NSRect)*/
/*
 The keypath of a BOOLean value indicating whether or not the sidebar was left enabled or disabled.  
 Can be unarchived and used to set up the UI.
 */
PUISSANT_EXPORT NSString *const PSTSidebarEnabled; /*BOOL*/
/*
 A keypath in Defaults.plist that points to a BOOLean value indicating whether there are enough accounts to
 necessitate the creation of a unified inbox.  While it is not necessarily accurate, it does help with guessing
 at the state the UI needs to be put in when it is dearchived from "cryo-sleep" in Lion+.
 */
PUISSANT_EXPORT NSString *const PSTUnifiedInboxEnabled; /*BOOL*/

PUISSANT_EXPORT NSString *const PSTSequenceFetchCountKey; /*NSUInteger*/

PUISSANT_EXPORT NSString *const PSTAvatarImageManagerDidUpdateNotification;

#pragma mark - Folder Types

/*
 * Enumeration of the folder types supported (note: not labels  Labels have one
 * type which we query the path of the folder for).
 */
typedef enum {
	PSTFolderTypeNone = 0,		//The folder is either invalid, or
								//not associated with any path on the server.
	PSTFolderTypeInbox = 1,		//The folder has the path INBOX.
	PSTFolderTypeNextSteps,		//A folder created for DotMail's purposes
								//to house all messages with an actionstep value
								//higher than PSTActionStepValueNone.  Should
								//never be retrieved from a sync, or sync'd.
	PSTFolderTypeStarred, 		//A folder that ∂points to either the starred or
								//flagged messages associated with an
								//account.
	PSTFolderTypeDrafts,			//The folder associated with drafts stored on
								//the server.
	PSTFolderTypeSent,			//The sent messages associated with this account
	PSTFolderTypeTrash,			//The trashed (but not archived iff Gmail)
								//messages folder for this account
	PSTFolderTypeLabel,			//The type or any label, no matter what it's
								//path is.
	PSTFolderTypeAllMail,		//The path to the allmail folder.
	PSTFolderTypeSpam,			//The path to the spam folder.
	PSTFolderTypeImportant,		//The path to the important folder, if supported
	PSTFolderTypeUnread			//The path to the unread messages folder.
} PSTFolderType;

#pragma mark - Error Handling

/*
 * The DotMail error domain.  Used with all NSError instances that are created by
 * DotMail itself.
 */
PUISSANT_EXPORT NSString *const PSTErrorDomain;

typedef NS_ENUM(NSInteger, PSTErrorConstants) {
	PSTErrorCannotAuthenticateWithoutPassword
};


#pragma mark - Action Steps

/*
 * ActionStep values.
 */
typedef NS_ENUM(int, PSTActionStepValue) {
	PSTActionStepValueNone = 0,
	PSTActionStepValueLow = 1,
	PSTActionStepValueMedium = 2,
	PSTActionStepValueHigh = 3
};

PUISSANT_EXPORT NSUInteger const kPSTAutoresizingMaskAll;

/**
 * Executes its map block over the entirety of the provided array and returns a new array of
 * the results.
 */
PUISSANT_EXPORT NSArray *PSTArrayMap(NSArray *inArray, id(^PSTArrayMapBlock)(id item));

/**
 * Given an array of paths, if a path is a file reference or a symbolic link that leads to a file
 * reference, then return the size of the file at that path. Else if the file is a directory, then 
 * recursively traverse its contents gathering the size of the directory in an accumulator.
 * 
 * The size of all paths after being traversed is totalled and returned in bytes.
 */
PUISSANT_EXPORT uint64_t PSTAccumulateDirectorySize(NSArray *inArray);

/**
 * Given an array, attempts to split the array into the provided number of parts, and fill each of
 * the slices as equally as possible.  If the number of parts cannot be safely divided, the original
 * array is returned through the `slices` reference.
 */
PUISSANT_EXPORT void PSTArrayDivide(NSArray **slices, NSArray *inArray, NSUInteger parts);

/**
 * Given an array, attempts to split the array into the provided number of parts, and fill each of
 * the slices as equally as possible.  If the number of parts cannot be safely divided, the original
 * array is returned through the `slices` reference.
 *
 * When the slicing process occurs, the array is searched for a folder named "INBOX", and
 * guarantees that it will always be in the first slice if found.
 */
PUISSANT_EXPORT void PSTPreferentialArrayDivide(NSArray **slices, NSArray *inArray, NSUInteger parts);

/**
 * Given an array, attempts to split the array into the provided number of parts, and fill each of
 * the slices as equally as possible by enumerating in reverse.  If the number of parts cannot be 
 * safely divided, the original array is returned through the `slices` reference.
 */
PUISSANT_EXPORT void PSTReverseArrayDivide(NSArray **slices, NSArray *inArray, NSUInteger parts);

/**
 * Given an index set, attempts to split the indexset into the provided number of parts, and fill
 * each of the slices as equally as possible.  If the number of parts cannot be safely divided, the
 * original indexSet is passed through in an array containing only one object.
 */
PUISSANT_EXPORT void PSTIndexSetDivide(NSArray **slices, NSIndexSet *inArray, NSUInteger parts);

/**
 * Given an index set, attempts to split the indexset into the provided number of parts, and fill
 * each of the slices as equally as possible by enumerating in reverse.  If the number of parts 
 * cannot be safely divided, the original indexSet is passed through in an array containing only one 
 * object.
 */
PUISSANT_EXPORT void PSTReverseIndexSetDivide(NSArray **slices, NSIndexSet *inArray, NSUInteger parts);

/**
 * Given an array of `MCOIMAPMessage`s, the array is enumerated and the UIDs of every message are
 * shuffled into an NSIndexSet.
 */
PUISSANT_EXPORT NSIndexSet *PSTIMAPMessageArrayToIndexSet(NSArray *array);

/**
 * Given an array of `NSNumber`s, return an NSIndexSet made from their integer
 * values.
 */
PUISSANT_EXPORT NSIndexSet *PSTIndexSetOfNumbers(NSArray *array);

PUISSANT_EXPORT MCOAbstractPart *PSTPreferredIMAPPart(NSArray *parts);

/**
 * Internal implementation of PSTLog(...).
 */
PUISSANT_EXPORT void LEPLogInternal(const char * filename, unsigned int line, int dumpStack, NSString * format, ...);

#endif
