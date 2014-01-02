//
//  NSImage+PSTBase64.m
//  Puissant
//
//  Created by Robert Widmann on 4/21/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import "NSImage+PSTBase64.h"
#include "Base64Transcoder.h"


@implementation NSData (NSData_Base64Extensions)

+ (id)dataWithBase64EncodedString:(NSString *)inString
{
    NSData *theEncodedData = [inString dataUsingEncoding:NSASCIIStringEncoding];
    size_t theDecodedDataSize = EstimateBas64DecodedDataSize([theEncodedData length], Base64Flags_IncludeNewlines);
    void *theDecodedData = malloc(theDecodedDataSize);
    Base64DecodeData([theEncodedData bytes], [theEncodedData length], theDecodedData, &theDecodedDataSize, 0);
    theDecodedData = reallocf(theDecodedData, theDecodedDataSize);
    if (theDecodedData == NULL)
        return(NULL);
    id theData = [self dataWithBytesNoCopy:theDecodedData length:theDecodedDataSize freeWhenDone:YES];
    return(theData);
}

#pragma mark -

- (NSData *)asBase64EncodedData:(NSInteger)inFlags;
{
    size_t theEncodedDataSize = EstimateBas64EncodedDataSize([self length], (int32_t)inFlags);
    NSMutableData *theEncodedData = [NSMutableData dataWithLength:theEncodedDataSize];
    Base64EncodeData([self bytes], [self length], [theEncodedData mutableBytes], &theEncodedDataSize, (int32_t)inFlags);
    return(theEncodedData);
}

- (NSData *)asBase64EncodedData
{
    return([self asBase64EncodedData:Base64Flags_IncludeNewlines]);
}

#pragma mark -

- (NSString *)asBase64EncodedString;
{
    return([self asBase64EncodedString:Base64Flags_Default]);
}

- (NSString *)asBase64EncodedString:(NSInteger)inFlags;
{
    inFlags |= Base64Flags_IncludeNullByte;
    size_t theEncodedDataSize = EstimateBas64EncodedDataSize([self length], (int32_t)inFlags | Base64Flags_IncludeNullByte);
    void *theEncodedData = malloc(theEncodedDataSize);
    Base64EncodeData([self bytes], [self length], theEncodedData, &theEncodedDataSize, (int32_t)inFlags | Base64Flags_IncludeNullByte);
    theEncodedData = reallocf(theEncodedData, theEncodedDataSize);
    if (theEncodedData == NULL)
        return(NULL);
    NSString *theString = [NSString stringWithUTF8String:theEncodedData];
    free(theEncodedData);
    return(theString);
}

@end

@implementation NSImage (PSTBase64)

- (NSString *)base64Representation {
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:self.TIFFRepresentation];
    NSData *imageData = [imageRep representationUsingType:NSPNGFileType properties:nil];
	return [@"data:image/png;base64," stringByAppendingString:[imageData asBase64EncodedString]];
}

@end
