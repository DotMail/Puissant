//
//  PSTIMAPFolderSynchronizer.m
//  DotMail
//
//  Created by Robert Widmann on 10/11/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTIMAPFolderSynchronizer.h"
#import <MailCore/mailcore.h>
#import "PSTDatabaseController+Operations.h"
#import "PSTFlagsUpdateBatcher.h"
#import "PSTActivity.h"
#import "PSTActivityManager.h"
#import "PSTLocalMessage.h"
#import "PSTIMAPAccountSynchronizer.h"
#import "NSIndexSet+PSTOperators.h"
#import "MCOAbstractMessage+LEPRecursiveAttachments.h"
#import "MCOAbstractPart+LEPRecursiveAttachments.h"
#import <ReactiveCocoa/EXTScope.h>

@interface PSTIMAPFolderSynchronizer ()

@property (nonatomic, strong) MCOIMAPFolder *folder;
@property (nonatomic, strong) RACSubject *flagsFetchSubject;
@property (nonatomic, strong) RACSubject *idleSubject;

@property (nonatomic, strong) PSTActivity *folderSyncActivity;

@property (nonatomic, strong) PSTFlagsUpdateBatcher *storeFlagsBatcher;

@property (nonatomic, strong) MCOIMAPSession *session;

@property (nonatomic, assign) BOOL canIdle;
@property (nonatomic, assign) NSUInteger totalMessagesCount;
@property (nonatomic, assign) NSUInteger fetchedMessagesCount;

@end

@implementation PSTIMAPFolderSynchronizer {
	dispatch_queue_t _callbackQueue;
}

#pragma mark - Life Cycle

- (id)initWithSession:(MCOIMAPSession *)session forFolder:(MCOIMAPFolder *)folder {
	self = [super init];

	_folder = folder;
	_flagsFetchSubject = [RACSubject subject];
	_idleSubject = [RACSubject subject];

	self.session = session;
	if ([folder.path isEqualToString:@"INBOX"]) self.canIdle = YES;
	self.totalMessagesCount = 0;
	self.fetchedMessagesCount = 0;

	_callbackQueue = dispatch_queue_create([NSString stringWithFormat:@"com.codafi.%@.%@.queue", session.username, folder.path].UTF8String, NULL);
	
	return self;
}

- (RACSignal *)sync {
	@weakify(self)
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		self.folderSyncActivity = [PSTActivity activityWithDescription:[NSString stringWithFormat:@"Syncing %@", self.folder.path] forFolderPath:self.folder.path email:self.session.username];
		MCOIMAPMessagesRequestKind requestKind = MCOIMAPMessagesRequestKindUid;
		MCOIMAPFetchMessagesOperation *request = [self.session fetchMessagesByUIDOperationWithFolder:self.folder.path requestKind:requestKind uids:[MCOIndexSet indexSetWithRange:MCORangeMake(1, UINT64_MAX)]];
		request.callbackDispatchQueue = _callbackQueue;
		[request start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
			if (error) {
//				[self.folderSyncActivity incrementProgressValue:1];
				[PSTActivityManager.sharedManager removeActivity:self.folderSyncActivity];
//				[subscriber sendError:error];
//				if (error.code == MCOErrorGmailTooManySimultaneousConnections) {
//					double delayInSeconds = 2.0;
//					dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
//					dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//						[[self sync]subscribe:subscriber];
//					});
//					return;
//				}
				[subscriber sendCompleted];
				return;
			}
			NSIndexSet *messageUIDs = PSTIMAPMessageArrayToIndexSet(messages);
			self.totalMessagesCount = messageUIDs.count;
			if (messageUIDs.count == 0) {
				[PSTActivityManager.sharedManager removeActivity:self.folderSyncActivity];
				[subscriber sendCompleted];
				return;
			}
			[[self.database addMessagesUIDsOperation:messageUIDs forFolder:self.folder] start:^() {
				__block NSUInteger iterations = 0;
				NSArray *dividedUIDs = nil;
				PSTReverseIndexSetDivide(&dividedUIDs, messageUIDs, roundtol(messageUIDs.count / 200));
				[self.folderSyncActivity setMaximumProgress:self.totalMessagesCount];
				[[self _dispatchDividedUIDs:dividedUIDs index:iterations] subscribeNext:^(id _) {
					[subscriber sendNext:self];
				} completed:^{
					iterations++;
					if (dividedUIDs.count > iterations) {
						[subscriber sendNext:self];
					} else {
						[subscriber sendNext:self];
						[PSTActivityManager.sharedManager removeActivity:self.folderSyncActivity];
						[subscriber sendCompleted];
					}
				}];
			}];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[request cancel];
		}];
	}];
}

- (RACSignal *)refreshSync {
	@weakify(self)
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		self.folderSyncActivity = [PSTActivity activityWithDescription:[NSString stringWithFormat:@"Refreshing %@", self.folder.path] forFolderPath:self.folder.path email:self.session.username];
		MCOIMAPMessagesRequestKind requestKind = MCOIMAPMessagesRequestKindUid;
		MCOIMAPFetchMessagesOperation *request = [self.session fetchMessagesByUIDOperationWithFolder:self.folder.path requestKind:requestKind uids:[MCOIndexSet indexSetWithRange:MCORangeMake(1, UINT64_MAX)]];
		request.callbackDispatchQueue = _callbackQueue;
		[request start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
			@strongify(self);
			if (error) {
				if (error.code == MCOErrorGmailTooManySimultaneousConnections) {
					double delayInSeconds = 2.0;
					dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
					dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
						@strongify(self);
						[PSTActivityManager.sharedManager removeActivity:self.folderSyncActivity];
						[[self refreshSync]subscribe:subscriber];
					});
					return;
				}
				[subscriber sendCompleted];
				[PSTActivityManager.sharedManager removeActivity:self.folderSyncActivity];
				[subscriber sendError:error];
				return;
			}
			NSIndexSet *messageUIDs = PSTIMAPMessageArrayToIndexSet(messages);
			self.totalMessagesCount = messageUIDs.count;
			if (messageUIDs.count == 0) {
				[PSTActivityManager.sharedManager removeActivity:self.folderSyncActivity];
				[subscriber sendCompleted];
				return;
			}
			[[self.database incompleteMessagesUIDOperationForFolder:self.folder lastUID:0 limit:200]start:^(NSIndexSet *messageUIDsSet) {
				NSMutableIndexSet *msgs = messageUIDsSet.mutableCopy;
				[[self.database messagesUIDsNotInDatabase:messages forFolder:self.folder]start:^(NSIndexSet *notInMsgs) {
					[msgs addIndexes:notInMsgs];
					[subscriber sendNext:self];
					[[self.database addMessagesUIDsOperation:notInMsgs forFolder:self.folder] start:^{
						__block NSUInteger iterations = 0;
						NSArray *dividedUIDs = nil;
						PSTReverseIndexSetDivide(&dividedUIDs, notInMsgs, roundtol(notInMsgs.count / 200));
						[self.folderSyncActivity setMaximumProgress:self.totalMessagesCount];
						[RACScheduler.scheduler scheduleRecursiveBlock:^(void(^reschedule)()) {
							[[self _dispatchDividedUIDs:dividedUIDs index:iterations] subscribeNext:^(id _) {
								[subscriber sendNext:self];
							} completed:^{
								iterations++;
								if (dividedUIDs.count > iterations) {
									[subscriber sendNext:self];
									reschedule();
								} else {
									[[self _fetchIncompleteMessages] subscribeNext:^(id x) {
										[subscriber sendNext:self];
									} completed:^{
										[subscriber sendNext:self];
										[PSTActivityManager.sharedManager removeActivity:self.folderSyncActivity];
										[subscriber sendCompleted];
										if (self.canIdle) {
											[[self.session idleOperationWithFolder:self.folder.path lastKnownUID:0]start:^(NSError *error) {
												[[self refreshSync]subscribe:subscriber];
											}];
										}
									}];
								}
							}];
						}];
					}];
				}];
			}];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[request cancel];
		}];
	}];
}


- (RACSignal *)syncWithOptions:(PSTFolderSynchronizerOptions)options {
	switch (options) {
		case PSTFolderSynchronizerOptionNone:
			return [self sync];
			break;
		case PSTFolderSynchronizerOptionIDLE:
			return [self idle];
			break;
		case PSTFolderSynchronizerOptionRefresh:
			return [self refreshSync];
			break;
		case PSTFolderSynchronizerOptionSyncPop:
			[[NSException exceptionWithName:@"PSTFeatureUnimplementedException" reason:@"POP is not yet supported by the framework" userInfo:nil]raise];
			break;
		case PSTFolderSynchronizerOptionPushModifiedMessages:
			return [self _startModifiedPush];
			break;
		default:
			break;
	}
	return nil;
}

- (RACSignal *)idle {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		[[self.session idleOperationWithFolder:self.folder.path lastKnownUID:0]start:^(NSError *error) {
			if (error) {
				[subscriber sendError:error];
			}
			[subscriber sendCompleted];
		}];
	}];
}

- (RACSignal *)_dispatchDividedUIDs:(NSArray *)dividedUIDs index:(NSUInteger)index {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		NSIndexSet *uidsSet = dividedUIDs[index];
		MCOIMAPMessagesRequestKind requestKind = (MCOIMAPMessagesRequestKindHeaders | MCOIMAPMessagesRequestKindStructure | MCOIMAPMessagesRequestKindInternalDate | MCOIMAPMessagesRequestKindHeaderSubject | MCOIMAPMessagesRequestKindFlags);
		MCOIMAPFetchMessagesOperation *req = [self.session fetchMessagesByUIDOperationWithFolder:self.folder.path requestKind:requestKind uids:[MCOIndexSet indexSetWithRange:MCORangeMake(uidsSet.firstIndex, uidsSet.lastIndex - uidsSet.firstIndex)]];
		req.callbackDispatchQueue = _callbackQueue;
		[req start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
			@strongify(self);
			if (error) {
				[subscriber sendError:error];
				[subscriber sendCompleted];
				return;
			}
			[subscriber sendNext:nil];
			[[self.database addMessagesOperation:messages markDeletedMessageID:nil folder:self.folder isDraft:self.isDraftSynchronizer] start:^{
				@strongify(self);
				[subscriber sendNext:nil];
				self.folderSyncActivity.progressValue = self.fetchedMessagesCount;
				self.folderSyncActivity.maximumProgress = self.totalMessagesCount;
				self.storeFlagsBatcher = [[PSTFlagsUpdateBatcher alloc]init];
				[self.storeFlagsBatcher setMessages:messages];
				[self.storeFlagsBatcher setFolder:self.folder];
				[self.storeFlagsBatcher setStorage:self.database];
				[self.storeFlagsBatcher startRequestWithCompletion:^{
					self.folderSyncActivity.activityDescription = [NSString stringWithFormat:@"Syncing %@ - %lu E-Mails remaining", self.folder.path, self.totalMessagesCount];
					[[self _fetchAllMessageBodies:messages.mutableCopy] subscribeCompleted:^{
						[subscriber sendCompleted];
					}];
				}];
			}];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[req cancel];
		}];
		
		return nil;
	}];
}

- (RACSignal *)_fetchAllMessageBodies:(NSMutableArray *)messages {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		NSUInteger fullMessageCount = messages.count;
		self.folderSyncActivity.maximumMetaProgress = fullMessageCount;
		__block NSUInteger index = 0;
		
		[RACScheduler.scheduler scheduleRecursiveBlock:^(void(^reschedule)()) {
			@strongify(self);
			index++;
			MCOIMAPMessage *tailMessage = [messages.lastObject copy];
			if (tailMessage == nil) return;
						
			self.folderSyncActivity.activityDescription = [NSString stringWithFormat:@"Syncing %@ - %lu E-Mails remaining", self.folder.path, self.totalMessagesCount - self.fetchedMessagesCount];
			self.fetchedMessagesCount++;
			[self.folderSyncActivity setProgressValue:self.fetchedMessagesCount];

			if (tailMessage.attachments.count != 0) {
				[[self _fetchAttachment:tailMessage.attachments fromMessage:tailMessage withIndex:0]subscribeCompleted:^{
					if (index >= fullMessageCount) {
						[subscriber sendCompleted];
						return;
					}
				}];
			}
			if (tailMessage.mainPart.plaintextTypeAttachments.count != 0) {
				[[self _fetchBodyAttachment:tailMessage.mainPart.plaintextTypeAttachments fromMessage:tailMessage withIndex:0]subscribeCompleted:^{
					if (index >= fullMessageCount) {
						[subscriber sendCompleted];
						return;
					}
				}];
			} else {
				MCOIMAPFetchContentOperation *request = [self.session fetchMessageByUIDOperationWithFolder:self.folder.path uid:tailMessage.uid];
				request.callbackDispatchQueue = _callbackQueue;
				[request start:^(NSError *error, NSData *data) {
					@strongify(self);
					if (error) {
						[subscriber sendError:error];
						[subscriber sendCompleted];
						return;
					}
					[[self.database addMessageContentOperation:tailMessage forFolder:self.folder data:data]startRequest];
					[self.folderSyncActivity incrementMetaProgressValue:1.f];
					if (index >= fullMessageCount) {
						[subscriber sendCompleted];
						return;
					}
					[messages removeLastObject];
					reschedule();
				}];
				return;
			}
			[self.folderSyncActivity incrementMetaProgressValue:1.f];
			[messages removeLastObject];
			reschedule();
		}];
		
		return nil;
	}];
}

- (RACSignal *)_fetchBodyAttachment:(NSArray *)attachments fromMessage:(MCOIMAPMessage *)msg withIndex:(NSUInteger)idx {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		if (attachments.count == 0) return nil;
		
		MCOIMAPPart *att = (MCOIMAPPart *)attachments[idx];
		MCOIMAPFetchContentOperation *req = [self.session fetchMessageAttachmentByUIDOperationWithFolder:self.folder.path uid:msg.uid partID:att.partID encoding:att.encoding];
		req.callbackDispatchQueue = _callbackQueue;
		[req start:^(NSError *error, NSData *data) {
			if (error) {
				[subscriber sendError:error];
				[subscriber sendCompleted];
				return;
			}
			[[self.database addMessageContentOperation:msg forFolder:self.folder data:data]startRequest];
			[[self.database addAttachmentOperation:att forMessage:msg inFolder:self.folder data:data]startRequest];
			if (idx == (attachments.count-1)) {
				[subscriber sendCompleted];
				return;
			}
			[[self _fetchAttachment:attachments fromMessage:msg withIndex:(idx + 1)]subscribe:subscriber];
		}];
		return nil;
	}];
}

- (RACSignal *)_fetchAttachment:(NSArray *)attachments fromMessage:(MCOIMAPMessage *)msg withIndex:(NSUInteger)idx {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		if (attachments.count == 0) return nil;
		
		MCOIMAPPart *att = (MCOIMAPPart *)attachments[idx];
		MCOIMAPFetchContentOperation *req = [self.session fetchMessageAttachmentByUIDOperationWithFolder:self.folder.path uid:msg.uid partID:att.partID encoding:att.encoding];
		req.callbackDispatchQueue = _callbackQueue;
		[req start:^(NSError *error, NSData *data) {
			if (error) {
				[subscriber sendError:error];
				[subscriber sendCompleted];
				return;
			}
			[[self.database addAttachmentOperation:att forMessage:msg inFolder:self.folder data:data]startRequest];
			if (idx == (attachments.count-1)) {
				[subscriber sendCompleted];
				return;
			}
			[[self _fetchAttachment:attachments fromMessage:msg withIndex:(idx + 1)]subscribe:subscriber];
		}];
		return nil;
	}];
}

- (void)cancel { }

- (RACSignal *)_startModifiedPush {
	@weakify(self);
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(self);
		[[self.database modifiedMessagesOperationForFolder:self.folder]start:^(NSMutableArray *mDelete, NSMutableArray *mPurge, NSMutableArray *mModify, NSMutableArray *mCopy) {
			NSArray *allToRemove = [mDelete arrayByAddingObjectsFromArray:mPurge];
			MCOIndexSet *allToAppendRead = [[MCOIndexSet alloc]init];
			MCOIndexSet *allToRemoveRead = [[MCOIndexSet alloc]init];
			
			for (MCOIMAPMessage *message in mModify) {
				if (message.originalFlags & MCOMessageFlagSeen) {
					if (!(message.flags & MCOMessageFlagSeen)) {
						[allToRemoveRead addIndex:message.uid];
					}
				} else {
					if (message.flags & MCOMessageFlagSeen) {
						[allToAppendRead addIndex:message.uid];
					}
				}
			}
			[[self.session storeFlagsOperationWithFolder:self.folder.path uids:allToRemoveRead kind:MCOIMAPStoreFlagsRequestKindRemove flags:MCOMessageFlagSeen]start:^(NSError *error) { }];
			[[self.session storeFlagsOperationWithFolder:self.folder.path uids:allToAppendRead kind:MCOIMAPStoreFlagsRequestKindAdd flags:MCOMessageFlagSeen]start:^(NSError *error) { }];
			
			if (self.trashSynchronizer) {
				[allToRemove enumerateObjectsUsingBlock:^(MCOIMAPMessage *msg, NSUInteger idx, BOOL *stop) {
					msg.flags |= MCOMessageFlagDeleted;
				}];
				[[self.session storeFlagsOperationWithFolder:self.folder.path uids:allToRemoveRead kind:MCOIMAPStoreFlagsRequestKindRemove flags:MCOMessageFlagSeen]start:^(NSError *error) { }];
			} else {
				MCOIndexSet *allUIDsToRemove = [[MCOIndexSet alloc]init];

				[allToRemove enumerateObjectsUsingBlock:^(MCOIMAPMessage *msg, NSUInteger idx, BOOL *stop) {
					[allUIDsToRemove addIndex:msg.uid];
				}];
				if (allUIDsToRemove.count != 0) {
					[[self.session copyMessagesOperationWithFolder:self.folder.path uids:allUIDsToRemove destFolder:self.parentSynchronizer.trashFolder.path]start:^(NSError *error, MCOIndexSet *destUids) {
						[[self.session storeFlagsOperationWithFolder:self.folder.path uids:allUIDsToRemove kind:MCOIMAPStoreFlagsRequestKindAdd flags:MCOMessageFlagDeleted]start:^(NSError *error) { }];
					}];
				}
			}
			[[self.database commitFlagsWithDirtyMessages:mModify]startRequest];
		}];
		return nil;
	}];
}


- (RACSignal *)_fetchIncompleteMessages {
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		[[self.database incompleteMessagesUIDOperationForFolder:self.folder lastUID:0 limit:NSUIntegerMax]start:^(NSIndexSet *uidsSet) {
			if (uidsSet.count ==  0) {
				[subscriber sendCompleted];
				return;
			}
			__block NSUInteger iterations = 0;
			NSArray *dividedUIDs = nil;
			PSTReverseIndexSetDivide(&dividedUIDs, uidsSet, roundtol(uidsSet.count / 200));
			[RACScheduler.scheduler scheduleRecursiveBlock:^(void(^reschedule)()) {
				[[self _dispatchDividedUIDs:dividedUIDs index:iterations] subscribeNext:^(id _) {
					[subscriber sendNext:self];
				} completed:^{
					iterations++;
					if (dividedUIDs.count > iterations) {
						[subscriber sendNext:self];
						reschedule();
					} else {
						[subscriber sendNext:self];
						[subscriber sendCompleted];
					}
				}];
			}];
		}];
		return nil;
	}];
}

@end
