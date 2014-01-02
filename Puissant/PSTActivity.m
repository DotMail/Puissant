//
//  PSTActivity.m
//  DotMail
//
//  Created by Robert Widmann on 11/18/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTActivity.h"
#import "PSTActivityManager.h"

@implementation PSTActivity

+ (PSTActivity *)activityWithDescription:(NSString *)desc forEmail:(NSString *)email {
	PSTActivity *retVal = [[self.class alloc] initWithDescription:desc forEmail:email];
	
	[PSTActivityManager.sharedManager registerActivity:retVal];
	
	return retVal;
}

+ (PSTActivity *)activityWithDescription:(NSString *)desc forFolderPath:(NSString *)forFolderPath email:(NSString *)email {
	PSTActivity *retVal = [[self.class alloc] initWithDescription:desc forEmail:email];
	[retVal setFolderPath:forFolderPath];
	
	[PSTActivityManager.sharedManager registerActivity:retVal];
	
	return retVal;
}

- (id)initWithDescription:(NSString *)desc forEmail:(NSString *)email {
	if (self = [super init]) {
		_activityDescription = desc;
		_email = email;
	}
	return self;
}

- (void)incrementProgressValue:(float)delta {
	self.progressValue += delta;
}

- (void)incrementMetaProgressValue:(float)delta {
	self.metaProgressValue += delta;
}

- (void)setMaximumProgress:(float)maximumProgress {
	_maximumProgress = maximumProgress;
	PSTPropogateValueForKey(self.percentValue, { });
}

- (void)setProgressValue:(float)progressValue {
	_progressValue = progressValue;
	PSTPropogateValueForKey(self.percentValue, { });
}

- (void)setMaximumMetaProgress:(float)maximumMetaProgress {
	_maximumMetaProgress = maximumMetaProgress;
	PSTPropogateValueForKey(self.metaPercentValue, { });
}

- (void)setMetaProgressValue:(float)progressValue {
	_metaProgressValue = progressValue;
	PSTPropogateValueForKey(self.metaPercentValue, { });
}


- (float)percentValue {
	if (self.maximumProgress == 0 || self.progressValue == 0) {
		return 0;
	}
	if (self.finished == NO) {
		return (self.progressValue / self.maximumProgress);
	}
	return 0;
}

- (float)metaPercentValue {
	if (self.maximumMetaProgress == 0 || self.metaProgressValue == 0) {
		return 0;
	}
	if (self.finished == NO) {
		return (self.metaProgressValue / self.maximumMetaProgress);
	}
	return 0;
}

- (BOOL)isEqual:(id)object {
	BOOL retVal = [super isEqual:object];
	if (!retVal) {
		retVal = [[object activityDescription]isEqualToString:self.activityDescription];
	}
	
	return retVal;
}

- (NSString *)description {
	NSMutableDictionary *descriptionDictionary = [NSMutableDictionary dictionary];
	if (self.email != nil) {
		[descriptionDictionary setObject:self.email forKey:@"Email"];
	}
	if (self.folderPath != nil) {
		[descriptionDictionary setObject:self.folderPath forKey:@"Path"];
	}
	if (self.activityDescription != nil) {
		[descriptionDictionary setObject:self.activityDescription forKey:@"Description"];
	}
	[descriptionDictionary setObject:@(self.progressValue) forKey:@"ProgressValue"];
	[descriptionDictionary setObject:@(self.maximumProgress) forKey:@"MaximumProgress"];
	return [descriptionDictionary description];
}

@end