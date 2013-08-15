//
//  SPAuthenticationConfiguration.h
//  Simperium-OSX
//
//  Created by Michael Johnston on 7/29/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPAuthenticationConfiguration : NSObject

@property (nonatomic, copy) NSString *regularFontName;
@property (nonatomic, copy) NSString *mediumFontName;
@property (nonatomic, copy) NSString *logoImageName;

+ (SPAuthenticationConfiguration *)sharedInstance;
- (float)regularFontHeightForSize:(float)size;

@end