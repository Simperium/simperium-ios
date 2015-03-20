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

@property (nonatomic, assign, readwrite) NSString   *forgotPasswordURL;
@property (nonatomic, assign, readwrite) NSString   *termsOfServiceURL;

#if !TARGET_OS_IPHONE
@property (nonatomic, strong) NSColor *controlColor;
#endif

+ (instancetype)sharedInstance;
- (float)regularFontHeightForSize:(float)size;

@end
