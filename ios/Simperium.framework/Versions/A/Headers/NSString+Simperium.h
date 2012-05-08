//
//  NSString+Simperium.h
//  Simperium
//
//  Created by Michael Johnston on 11-06-03.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString(NSString_Simperium)

+ (NSString *)encodeBase64WithString:(NSString *)strData;
+ (NSString *)encodeBase64WithData:(NSData *)objData;
+ (NSString *)makeUUID;
+ (NSString *)md5StringFromData:(NSData *)data;
- (NSString *)urlEncodeString;

@end
