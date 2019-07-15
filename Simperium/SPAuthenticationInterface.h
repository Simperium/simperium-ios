#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

#pragma mark ====================================================================================
#pragma mark SPAuthenticationInterface
#pragma mark ====================================================================================

@protocol SPAuthenticationInterface <NSObject>

/// Simperium Authentication API's
///
@property (nonatomic, strong) SPAuthenticator *authenticator;

/// Indicates if the Authentication Dialog should be dismissable
///
@property (nonatomic, assign) BOOL optional;

@optional

/// Hints if the UI should be initially rendered in SignIn mode. That is: if the user was previously logged in.
///
@property (nonatomic, assign) BOOL signingIn;

@end

NS_ASSUME_NONNULL_END
