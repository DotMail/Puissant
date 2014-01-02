//
//  PSTMimeManager.h
//  Puissant
//
//  Created by Robert Widmann on 6/16/13.
//  Copyright (c) 2013 CodaFi. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * PSTMimeManager manages identifying a given filename or mimetype, and converting to and from common MIME types.
 * Currently supported MIME types:
 *
 * Images:
 * image/jpeg
 * image/gif
 * image/png
 * image/tiff
 * image/tif
 * image/bmp
 *
 * Archives (compressed files):
 * zip (application/zip)
 * sfark
 * s7z
 * ace
 * cpt
 * dar
 * pit
 * sea
 * sit
 * par
 * par2
 * gz
 * tgz
 * bz2
 * tbz
 * Z
 * taz
 * lz
 * tlz
 * 7z
 *
 * Other:
 * text/calendar (ics)
 * message/rfc822 (eml)
*/

@interface PSTMimeManager : NSObject

/**
 * The default initializer for this class.
 */
+ (instancetype)sharedManager;

/** Returns whether or not a given file is a PDF based on it's path extension.
 
 @param filename An NSString containing the full name of the file.
 @return BOOL.
 */
- (BOOL)isFileTypePDF:(NSString *)filename;

/** Returns whether or not a given file is an image based on it's path extension.
 
 @param filename An NSString containing the full name of the file.
 @return BOOL.
 */
- (BOOL)isFileTypeImage:(NSString *)filename;

/** Returns whether or not a given file is an archive (see above) based on it's path extension.
 
 @param filename An NSString containing the full name of the file.
 @return BOOL.
 */
- (BOOL)isFileTypeZip:(NSString *)filename;

/** Returns whether or not a given file is a PDF based on it's MIME type.
 
 @param mimeType An NSString containing the MIME type of the file.
 @return BOOL.
 */
- (BOOL)isMimeTypePDF:(NSString *)mimeType;

/** Returns whether or not a given file is an image based on it's MIME type.
 
 @param mimeType An NSString containing the MIME type of the file.
 @return BOOL.
 */
- (BOOL)isMimeTypeImage:(NSString *)mimeType;

/** Returns the MIME type for a given file name.
 
 @param filename An NSString containing the full name of the file.
 @return An NSString containing the MIME type for the given file.
 */
- (NSString *)mimeTypeForFile:(NSString *)filename;

/** Returns the file extension for a given MIME type.
 
 @param mimeType An NSString containing the MIME type of the file.
 @return An NSString containing the extension for a given MIME type.
 */
- (NSString *)pathExtensionForMimeType:(NSString *)mimeType;

@end
