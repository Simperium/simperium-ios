//
//  SPAuthenticationConfiguration.m
//  Simperium-OSX
//
//  Created by Michael Johnston on 7/29/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPAuthenticationConfiguration.h"

@implementation SPAuthenticationConfiguration

static SPAuthenticationConfiguration *gInstance = NULL;

+ (SPAuthenticationConfiguration *)sharedInstance
{
    @synchronized(self)
    {
        if (gInstance == NULL)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

- (id)init {
    if ((self = [super init])) {
        _regularFontName = @"HelveticaNeue";
        _mediumFontName = @"HelveticaNeue-Medium";
    }
    
    return self;
}

// Just quick and dirty fonts for now. Could be extended with colors.
// In an app this would likely be done in an external .plist file, but for a framework,
// keeping in code avoids having to include a resource.
#if TARGET_OS_IPHONE

// TODO: iPhone support
- (float)regularFontHeightForSize:(float)size {
    return 0;
}

#else

- (NSFont *)regularFontWithSize:(CGFloat)size {
    return [NSFont fontWithName:_regularFontName size:size];
}

- (NSFont *)mediumFontWithSize:(CGFloat)size {
    return [NSFont fontWithName:_mediumFontName size:size];
}

- (float)regularFontHeightForSize:(float)size {
    NSDictionary *attributes = @{NSFontAttributeName : [self regularFontWithSize:size],
                                 NSFontSizeAttribute : [NSString stringWithFormat:@"%f", size]};
    NSString *testStr = @"Testyj";
    return [testStr sizeWithAttributes:attributes].height;
}
#endif



@end
