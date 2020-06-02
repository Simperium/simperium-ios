//
//  SPAuthenticationValidator.m
//  Simperium-OSX
//
//  Created by Michael Johnston on 8/14/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPAuthenticationValidator.h"
#import "NSError+Simperium.h"
#import "NSString+Simperium.h"

static NSInteger SPAuthenticationDefaultMinPasswordLength = 8;
static NSInteger SPAuthenticationLegacyMinPasswordLength = 4;

NSString* const SPAuthenticationErrorDomain = @"SPAuthenticationValidatorDomain";

@implementation SPAuthenticationValidator

- (instancetype)init {
    self = [super init];
    if (self) {
        self.strongMinimumPasswordLength = SPAuthenticationDefaultMinPasswordLength;
        self.legacyMinimumPasswordLength = SPAuthenticationLegacyMinPasswordLength;
    }
    
    return self;
}

- (BOOL)isValidEmail:(NSString *)checkString {
    // From http://stackoverflow.com/a/3638271/1379066
    NSString *emailRegex = @".+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2}[A-Za-z]*";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    
    return [emailTest evaluateWithObject:checkString];
}

- (BOOL)validateUsername:(NSString *)username error:(NSError **)error {
    if ([self isValidEmail:username]) {
        return YES;
    }

    if (error) {
        NSString *description = NSLocalizedString(@"Not a valid email address", @"Error when you enter a bad email address");

        *error = [NSError sp_errorWithDomain:SPAuthenticationErrorDomain
                                        code:SPAuthenticationErrorsEmailInvalid
                                 description:description];
    }

    return NO;
}

- (BOOL)validatePasswordWithUsername:(NSString *)username password:(NSString *)password error:(NSError **)error {
    if (password.length < self.strongMinimumPasswordLength) {
        if (error) {
            NSString *description = NSLocalizedString(@"Password must contain at least %d characters", comment: @"Message displayed when password is too short. Please preserve the Percent D!");
            NSString *formattedDescription = [NSString stringWithFormat:description, self.strongMinimumPasswordLength];

            *error = [NSError sp_errorWithDomain:SPAuthenticationErrorDomain
                                            code:SPAuthenticationErrorsPasswordTooShort
                                     description:formattedDescription];
        }
        return NO;
    }

    if ([username isEqualToString:password]) {
        if (error) {
            NSString *description = NSLocalizedString(@"Password cannot match email", @"Message displayed when password is invalid (Signup)");
            *error = [NSError sp_errorWithDomain:SPAuthenticationErrorDomain
                                            code:SPAuthenticationErrorsPasswordMatchesUsername
                                     description:description];
        }

        return NO;
    }


    if ([password containsString:NSString.sp_newline] || [password containsString:NSString.sp_tab]) {
        if (error) {
            NSString *description = NSLocalizedString(@"Password must not contain tabs nor newlines", comment: @"Message displayed when a password contains a disallowed character");
            *error = [NSError sp_errorWithDomain:SPAuthenticationErrorDomain
                                            code:SPAuthenticationErrorsPasswordContainsInvalidCharacter
                                     description:description];
        }

        return NO;
    }
    
    // Could enforce other requirements here
    return YES;
}

- (BOOL)validatePasswordConfirmation:(NSString *)confirmation password:(NSString *)password error:(NSError **)error {
    if ([confirmation isEqualToString:confirmation]) {
        return YES;
    }

    if (error) {
        NSString *description = NSLocalizedString(@"Passwords do not match", @"Password Validation: Confirmation doesn't match");
        *error = [NSError sp_errorWithDomain:SPAuthenticationErrorDomain
                                        code:SPAuthenticationErrorsConfirmationDoesntMatch
                                 description:description];
    }

    return NO;
}

- (BOOL)mustPerformPasswordResetWithUsername:(NSString *)username password:(NSString *)password {
    BOOL isValidUsername = [self validateUsername:username error:nil];
    BOOL isValidLegacyPassword = (password.length >= self.legacyMinimumPasswordLength);
    BOOL isValidStrongPassword = [self validatePasswordWithUsername:username password:password error:nil];

    return isValidUsername && isValidLegacyPassword && !isValidStrongPassword;
}

@end
