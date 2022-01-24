//
//  AWFileHash.h
//  Pods
//
//  Created by Alexander Widerberg on 2015-02-17.
//
//

#import <Foundation/Foundation.h>

@interface AWFileHash : NSObject

+ (NSString *)md5HashOfData:(NSData *)data;
+ (NSString *)sha1HashOfData:(NSData *)data;
+ (NSString *)sha512HashOfData:(NSData *)data;
+ (NSString *)crc32HashOfData:(NSData *)data;

+ (NSString *)md5HashOfFileAtPath:(NSString *)filePath;
+ (NSString *)sha1HashOfFileAtPath:(NSString *)filePath;
+ (NSString *)sha512HashOfFileAtPath:(NSString *)filePath;
+ (NSString *)crc32HashOfFileAtPath:(NSString *)filePath;

@end
