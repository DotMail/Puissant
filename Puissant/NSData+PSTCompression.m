//
//  NSData+PSTCompression.m
//  Puissant
//
//  Created by Robert Widmann on 12/8/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "NSData+PSTCompression.h"
#include <zlib.h>

#define kMemoryChunkSize		1024
#define kFileChunkSize			(128 * 1024) //128Kb

@implementation NSData (PSTCompression)

+(NSData*)dmArchivedData:(id)object {
	return [NSKeyedArchiver archivedDataWithRootObject:object];
}

- (id)dmUnArchivedData:(NSData*)object {
	return [NSKeyedUnarchiver unarchiveObjectWithData:object];
}

//TODO replace with PSTArchiver
- (id)dataByStandardArchiving {
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}

//TODO replace with PSTUnArchiver
- (id)dataByStandardUnarchiving {
	return [NSKeyedUnarchiver unarchiveObjectWithData:self];
}

//See http://polkit.googlecode.com/svn/trunk/Extensions/NSData+GZip.m
- (NSData*)dataByGZipInflation {
	NSUInteger		length = [self length];
	int				windowBits = 15 + 16, //Default + gzip header instead of zlib header
	retCode;
	unsigned char	output[kMemoryChunkSize];
	uInt			gotBack;
	NSMutableData*	result;
	z_stream		stream;
	uLong			size;
	
	if((length == 0) || (length > UINT_MAX)) //FIXME: Support 64 bit inputs
		return nil;
	
	//FIXME: Remove support for original implementation of -compressGZip which wasn't generating real gzip data
	if((length >= sizeof(unsigned int)) && ((*((unsigned char*)[self bytes]) != 0x1F) || (*((unsigned char*)[self bytes] + 1) != 0x8B))) {
		size = NSSwapBigIntToHost(*((unsigned int*)[self bytes]));
		result = (size < 0x40000000 ? [NSMutableData dataWithLength:size] : nil); //HACK: Prevent allocating more than 1 Gb
		if(result && (uncompress([result mutableBytes], &size, (unsigned char*)[self bytes] + sizeof(unsigned int), [self length] - sizeof(unsigned int)) != Z_OK))
			result = nil;
		return result;
	}
	
	bzero(&stream, sizeof(z_stream));
	stream.avail_in = (uInt)length;
	stream.next_in = (unsigned char*)[self bytes];
	
	retCode = inflateInit2(&stream, windowBits);
	if(retCode != Z_OK) {
		PSTLog(@"%s: inflateInit2() failed with error %i", __FUNCTION__, retCode);
		return nil;
	}
	
	result = [NSMutableData dataWithCapacity:(length * 4)];
	do {
		stream.avail_out = kMemoryChunkSize;
		stream.next_out = output;
		retCode = inflate(&stream, Z_NO_FLUSH);
		if ((retCode != Z_OK) && (retCode != Z_STREAM_END)) {
			PSTLog(@"%s: inflate() failed with error %i", __FUNCTION__, retCode);
			inflateEnd(&stream);
			return nil;
		}
		gotBack = kMemoryChunkSize - stream.avail_out;
		if(gotBack > 0)
			[result appendBytes:output length:gotBack];
	} while(retCode == Z_OK);
	inflateEnd(&stream);
	
	return (retCode == Z_STREAM_END ? result : nil);
}

- (NSData*)dataByGzipDeflation {
	NSUInteger		length = [self length];
	int				windowBits = 15 + 16, //Default + gzip header instead of zlib header
	memLevel = 8, //Default
	retCode;
	NSMutableData*	result;
	z_stream		stream;
	unsigned char	output[kMemoryChunkSize];
	uInt			gotBack;
	
	if((length == 0) || (length > UINT_MAX)) //FIXME: Support 64 bit inputs
		return nil;
	
	bzero(&stream, sizeof(z_stream));
	stream.avail_in = (uInt)length;
	stream.next_in = (unsigned char*)[self bytes];
	
	retCode = deflateInit2(&stream, Z_BEST_COMPRESSION, Z_DEFLATED, windowBits, memLevel, Z_DEFAULT_STRATEGY);
	if(retCode != Z_OK) {
		PSTLog(@"%s: deflateInit2() failed with error %i", __FUNCTION__, retCode);
		return nil;
	}
	
	result = [NSMutableData dataWithCapacity:(length / 4)];
	do {
		stream.avail_out = kMemoryChunkSize;
		stream.next_out = output;
		retCode = deflate(&stream, Z_FINISH);
		if((retCode != Z_OK) && (retCode != Z_STREAM_END)) {
			PSTLog(@"%s: deflate() failed with error %i", __FUNCTION__, retCode);
			deflateEnd(&stream);
			return nil;
		}
		gotBack = kMemoryChunkSize - stream.avail_out;
		if(gotBack > 0)
			[result appendBytes:output length:gotBack];
	} while(retCode == Z_OK);
	deflateEnd(&stream);
	
	return (retCode == Z_STREAM_END ? result : nil);
}

//- (NSData*)dataBySnappyCompression {
//	size_t compressedLen = snappy_max_compressed_length(self.length);
//	NSMutableData *result =  [NSMutableData dataWithLength:(snappy_max_compressed_length(compressedLen + 0x4))];
//	snappy_status opCode = snappy_compress([self bytes], [self length], [result mutableBytes], &compressedLen);
//	if (opCode != SNAPPY_OK) {
//		PSTLog(@"Failed snappy compress: tried to compress %lu bytes", result.length);
//		NSAssert(nil, @"Failed Snappy compress");
//		result = nil;
//	} else {
//		[result setLength:compressedLen + 4];
//	}
//	return result;
//}
//
//- (NSData*)dataBySnappyUncompression {
//	NSMutableData *result = nil;
//	if (self.length < 4) {
//		return [self dataByGZipInflation];
//	}
//	if (self.bytes != NULL) {
//		size_t uncompress_result = 0;
//		snappy_status opCode = snappy_uncompressed_length(self.bytes, self.length, &uncompress_result);
//		if (opCode == SNAPPY_OK) {
//			result = [NSMutableData dataWithLength:uncompress_result];
//			opCode = snappy_uncompress(self.bytes, self.length, [result mutableBytes], &uncompress_result);
//			if (opCode == SNAPPY_OK) {
//				[result setLength:uncompress_result];
//				return result;
//			}
//		}
//	}
////	PSTLog(@"Failed snappy de-compress: tried to de-compress %lu bytes", self.length);
////	NSAssert(nil, @"Failed Snappy de-compress");
////	result = nil;
//	return result;
//}

@end
