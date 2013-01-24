//
//  SPSimpleKeyChain.h
//  Simperium
//
//  Created by Michael Johnston on 12-08-01.
//  Copyright (c) 2012 Simperium. All rights reserved.
//
// http://stackoverflow.com/questions/5247912/saving-email-password-to-keychain-in-ios/5251820#5251820

#import <Foundation/Foundation.h>

#import <Foundation/Foundation.h>

@interface SPSimpleKeychain : NSObject

+ (void)save:(NSString *)service data:(id)data;
+ (id)load:(NSString *)service;
+ (void)delete:(NSString *)service;

@end