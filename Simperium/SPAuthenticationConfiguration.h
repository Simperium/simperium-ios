//
//  SPAuthenticationConfiguration.h
//  Simperium-OSX
//
//  Created by Michael Johnston on 7/29/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


#pragma mark ====================================================================================
#pragma mark SPAuthenticationConfiguration
#pragma mark ====================================================================================

@interface SPAuthenticationConfiguration : NSObject

@property (nonatomic, copy,   readwrite) NSString   *regularFontName;
@property (nonatomic, copy,   readwrite) NSString   *mediumFontName;
@property (nonatomic, copy,   readwrite) NSString   *logoImageName;

@property (nonatomic, strong, readwrite) NSString   *forgotPasswordURL;
@property (nonatomic, strong, readwrite) NSString   *termsOfServiceURL;

@property (nonatomic, assign, readwrite) BOOL       previousUsernameEnabled;
@property (nonatomic, strong, readwrite) NSString   *previousUsernameLogged;

#if !TARGET_OS_IPHONE
@property (nonatomic, strong, readwrite) NSColor    *controlColor;
#endif

+ (instancetype)sharedInstance;
- (float)regularFontHeightForSize:(float)size;

@end
