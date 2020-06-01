//
//  SPAuthenticationValidator.h
//  Simperium-OSX
//
//  Created by Michael Johnston on 8/14/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SPAuthenticationErrors) {
    SPAuthenticationErrorsEmailInvalid,
    SPAuthenticationErrorsPasswordTooShort,
    SPAuthenticationErrorsPasswordMatchesUsername,
    SPAuthenticationErrorsPasswordContainsInvalidCharacter
};

extern NSString* const SPAuthenticationErrorDomain;

@interface SPAuthenticationValidator : NSObject

@property (nonatomic, assign) NSUInteger strongMinimumPasswordLength;
@property (nonatomic, assign) NSUInteger legacyMinimumPasswordLength;

- (BOOL)validateUsername:(NSString *)username
                   error:(NSError **)error;

- (BOOL)validatePasswordWithUsername:(NSString *)username
                            password:(NSString *)password
                               error:(NSError **)error;

- (BOOL)mustPerformPasswordResetWithUsername:(NSString *)username
                                    password:(NSString *)password;

@end
