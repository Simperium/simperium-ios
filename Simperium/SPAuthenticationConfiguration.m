//
//  SPAuthenticationConfiguration.m
//  Simperium-OSX
//
//  Created by Michael Johnston on 7/29/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPAuthenticationConfiguration.h"
#import "SPEnvironment.h"
#import "NSString+Simperium.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif


#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString *SPAuthenticationDefaultRegularFontName = @"HelveticaNeue";
static NSString *SPAuthenticationDefaultMediumFontName  = @"HelveticaNeue-Medium";
static NSString *SPAuthenticationTestString             = @"Testyj";


#pragma mark ====================================================================================
#pragma mark SPAuthenticationConfiguration
#pragma mark ====================================================================================

@implementation SPAuthenticationConfiguration

+ (instancetype)sharedInstance
{
    static SPAuthenticationConfiguration *_instance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    
    return _instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _regularFontName    = SPAuthenticationDefaultRegularFontName;
        _mediumFontName     = SPAuthenticationDefaultMediumFontName;
        _termsOfServiceURL  = SPTermsOfServiceURL;
        
#if !TARGET_OS_IPHONE
        _controlColor       = [NSColor colorWithCalibratedRed:65.f/255.f green:137.f/255.f blue:199.f/255.f alpha:1.0];
#endif
    }
    
    return self;
}


#pragma mark - Custom Setters

- (void)setForgotPasswordURL:(NSString *)forgotPasswordURL {
    NSAssert(!forgotPasswordURL || forgotPasswordURL.sp_isValidUrl, @"Simperium: Invalid Forgot Password URL");
    _forgotPasswordURL = forgotPasswordURL;
}

- (void)setTermsOfServiceURL:(NSString *)termsOfServiceURL {
    NSAssert(!termsOfServiceURL || termsOfServiceURL.sp_isValidUrl, @"Simperium: Invalid Terms of Service URL");
    _termsOfServiceURL = termsOfServiceURL;
}


#pragma mark - Font Helpers

#if TARGET_OS_IPHONE

- (float)regularFontHeightForSize:(float)size {
    return [SPAuthenticationTestString sizeWithFont:[UIFont fontWithName:self.regularFontName size:size]].height;
}

#else

- (NSFont *)regularFontWithSize:(CGFloat)size {
    return [NSFont fontWithName:_regularFontName size:size];
}

- (NSFont *)mediumFontWithSize:(CGFloat)size {
    return [NSFont fontWithName:_mediumFontName size:size];
}

- (float)regularFontHeightForSize:(float)size {
    NSDictionary *attributes = @{
        NSFontAttributeName : [self regularFontWithSize:size],
        NSFontSizeAttribute : [NSString stringWithFormat:@"%f", size]
    };
    
    return [SPAuthenticationTestString sizeWithAttributes:attributes].height;
}
#endif

@end
