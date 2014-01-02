//
//  PSTArchiver.m
//  Puissant
//
//  Created by Robert Widmann on 12/1/12.
//  Copyright (c) 2012 CodaFi. All rights reserved.
//

#import "PSTArchiver.h"

Class stringClass;
Class dataClass;
Class dictClass;
Class arrayClass;

@implementation PSTArchiver

- (id)init {
	if (self = [super init]) {
		self.data = [[NSMutableData alloc]init];
		[self.data appendBytes:"dmailwdt" length:0x8];
	}
	return self;
}

- (id)initWithData:(NSMutableData*)newData {
	if (self = [super init]) {
		self.data = newData;
		[self.data appendBytes:"dmailwdt" length:8];
	}
	return self;
}

- (BOOL)allowsKeyedCoding {
	return YES;
}

- (void)_encodeObject:(id)object {
	NULDBDecodedObject(NULDBEncodedObject(object));
}


- (void)encodeObject:(id)objv forKey:(NSString *)key {
	if (objv == nil) {
		return;
	} else {
		[self _encodeObject:objv];
	}
}

- (void)_encodeArrayItems:(NSArray*)array {
	for (id object in array) {
		[self _encodeObject:array];
	}
	[self _encodeObject:nil];
}

- (void)_encodeArray:(NSArray*)array {
	//	PSTEncodeType(self.data, 0x4);
	[self _encodeArrayItems:array];
}

- (void)_encodeDictionary:(NSDictionary*)dictionary {
	//	PSTEncodeType(self.data, 0x3);
	for (id key in [dictionary allKeys]) {
		[self _encodeObject:dictionary]; //unsure
		[self _encodeObject:[dictionary objectForKey:key]];
	}
	[self _encodeObject:nil];
}

- (void)_encodeSet:(NSSet*)set {
	//	PSTEncodeType(self.data, 0x5);
	[self _encodeArrayItems:[set allObjects]];
}

- (void)encodeBool:(BOOL)boolv forKey:(NSString *)key {
	//	PSTEncode(self.data, key);
	//	PSTEncode(self.data, @(boolv));
}

- (void)encodeInt:(int)intv forKey:(NSString *)key {
	//	PSTEncode(self.data, key);
	//	PSTEncode(self.data, @(intv));
}

- (void)encodeInt32:(int32_t)intv forKey:(NSString *)key {
	//	PSTEncode(self.data, key);
	//	PSTEncode(self.data, @(intv));
}

- (void)encodeInt64:(int64_t)intv forKey:(NSString *)key {
	//	PSTEncode(self.data, key);
	//	PSTEncode(self.data, @(intv));
}

- (void)encodeFloat:(float)realv forKey:(NSString *)key {
	//	PSTEncode(self.data, key);
	//	PSTEncode(self.data, @(realv));
}

- (void)encodeDouble:(double)realv forKey:(NSString *)key {
	//	PSTEncode(self.data, key);
	//	PSTEncode(self.data, @(realv));
}

+ (NSData *)archivedObject:(id)object {
	return [PSTArchiver archivedObject:object length:0x200];
}

+ (NSData *)archivedObject:(id)object length:(NSUInteger)length {
	NSMutableData *result = [NSMutableData dataWithCapacity:length];
	PSTArchiver *archiver = [[PSTArchiver alloc]initWithData:result];
	[archiver _encodeObject:object];
	return result;
}

- (void)encodeConditionalObject:(id)objv forKey:(NSString *)key {
	return [self encodeObject:objv forKey:key];
}

- (void)encodeBytes:(const uint8_t *)bytesp length:(NSUInteger)lenv forKey:(NSString *)key {
	[self encodeObject:[[NSData alloc]initWithBytesNoCopy:(void*)bytesp length:lenv freeWhenDone:NO] forKey:key];
}

NSData *NULDBEncodedObject(id<NSCoding>object) {
	
	char type = 'o';
	
	if([(id)object isKindOfClass:stringClass])    type = 's';
	else if([(id)object isKindOfClass:dataClass]) type = 'd';
	else if([(id)object isKindOfClass:dictClass] || [(id)object isKindOfClass:arrayClass]) type = 'h';
	
	NSMutableData *d = [NSMutableData dataWithBytes:&type length:1];
	
	switch (type) {
		case 's':
			[d appendData:[(NSString *)object dataUsingEncoding:NSUTF8StringEncoding]];
			break;
			
		case 'd':
			[d appendData:(NSData *)object];
			break;
			
		case 'h':
			[d appendData:[NSPropertyListSerialization dataWithPropertyList:(id)object format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL]];
			break;
			
		default:
			[d appendData:[NSKeyedArchiver archivedDataWithRootObject:object]];
			break;
	}
	
	return d;
}

extern id NULDBDecodedObject(NSData *data) {
	
	NSData *value = [data subdataWithRange:NSMakeRange(1, [data length] - 1)];
	
	char type;
	
	[data getBytes:&type length:1];
	
	switch (type) {
		case 's':
			return [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
			break;
			
		case 'd':
			return value;
			break;
			
		case 'h':
			return [NSPropertyListSerialization propertyListWithData:value options:NSPropertyListImmutable format:NULL error:NULL];
			break;
			
		default:
			break;
	}
	
	return [NSKeyedUnarchiver unarchiveObjectWithData:value];
}


@end

@interface PSTUnarchiver ()

@property (nonatomic, strong) NSMutableArray *stack;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) int offset;
@property (nonatomic, assign) BOOL valid;

@end

@implementation PSTUnarchiver

- (id)initWithData:(NSData*)newData {
	if (self = [super init]) {
		self.stack = [[NSMutableArray alloc]init];
		self.data = newData;
		self.offset = 0;
		if (self.data.length < 8) {
			return self;
		}
		int egalite = strncmp([self.data bytes], "dmailwdt", 0x8);
		if (egalite != 0) {
			int plistE = strncmp([self.data bytes], "bplist00", 0x8);
			if (plistE != 0) {
				return self;
			}
		}
		self.offset += 8;
		self.valid = YES;
		return self;
	}
	return self;
}

+(id)unarchivedObject:(NSData*)dataToDearchive {
	return [[PSTUnarchiver alloc]initWithData:dataToDearchive];
}

- (id)decodeObjectForKey:(NSString*)key {
	return [[self.stack lastObject]objectForKey:key];
}

@end
