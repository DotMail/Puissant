//
//  Base64Transcoder.h
//  TouchCode
//
//  Created by Jonathan Wight on Tue Mar 18 2003.
//  Copyright 2011 toxicsoftware.com. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
//  permitted provided that the following conditions are met:
//
//     1. Redistributions of source code must retain the above copyright notice, this list of
//        conditions and the following disclaimer.
//
//     2. Redistributions in binary form must reproduce the above copyright notice, this list
//        of conditions and the following disclaimer in the documentation and/or other materials
//        provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY JONATHAN WIGHT ``AS IS'' AND ANY EXPRESS OR IMPLIED
//  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL JONATHAN WIGHT OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  The views and conclusions contained in the software and documentation are those of the
//  authors and should not be interpreted as representing official policies, either expressed
//  or implied, of toxicsoftware.com.

#include <stdlib.h>
#include <stdbool.h>
#include <sys/types.h>

typedef enum {
	Base64Flags_None = 0x00,
	Base64Flags_IncludeNewlines = 0x01,
	Base64Flags_IncludeNullByte = 0x02,
	Base64Flags_Default = Base64Flags_IncludeNewlines | Base64Flags_IncludeNullByte,
} EBase64Flags;

extern size_t EstimateBas64EncodedDataSize(size_t inDataSize, int32_t inFlags);
extern size_t EstimateBas64DecodedDataSize(size_t inDataSize, int32_t inFlags);

extern ssize_t Base64EncodeData(const void *inInputData, size_t inInputDataSize, char *outOutputData, size_t *ioOutputDataSize, int32_t inFlags);
extern ssize_t Base64DecodeData(const void *inInputData, size_t inInputDataSize, void *ioOutputData, size_t *ioOutputDataSize, int32_t inFlags);
