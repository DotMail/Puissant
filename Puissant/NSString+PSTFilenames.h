//
//  NSString+PSTFilenames.h
//  Puissant
//
//  Created by Robert Widmann on 12/2/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (PSTFilenames)

+(NSString*)dmAttachmentFilenameWithBasePath:(NSString*)basePath filename:(NSString*)filename mimeType:(NSString*)mimeType defaultName:(NSString*)defaultName withExtension:(NSString*)extension;
+(NSString*)dmAttachmentFilenameWithBasePath:(NSString*)basePath filename:(NSString*)filename mimeType:(NSString*)mimeType;

@end
