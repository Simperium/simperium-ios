//
//  SPAuthenticator.m
//  Simperium
//
//  Created by Michael Johnston on 12-02-27.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "Simperium.h"
#import "Simperium+Internals.h"
#import "SPEnvironment.h"
#import "SPUser.h"
#import "SPAuthenticator.h"
#import "SPKeychain.h"
#import "SPReachability.h"
#import "SPLogger.h"
#import "NSURLRequest+Simperium.h"
#import "NSURLResponse+Simperium.h"
#import "NSURLSession+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static SPLogLevels logLevel     = SPLogLevelsInfo;
static NSString * SPUsername    = @"SPUsername";


#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPAuthenticator()
@property (nonatomic, strong, readwrite) SPReachability                 *reachability;
@property (nonatomic,   weak, readwrite) id<SPAuthenticatorDelegate>    delegate;
@property (nonatomic,   weak, readwrite) Simperium                      *simperium;
@property (nonatomic, assign, readwrite) BOOL                           connected;
@end


#pragma mark ====================================================================================
#pragma mark SPAuthenticator
#pragma mark ====================================================================================

@implementation SPAuthenticator

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithDelegate:(id<SPAuthenticatorDelegate>)authDelegate simperium:(Simperium *)s {
    self = [super init];
    if (self) {
        _delegate   = authDelegate;
        _simperium  = s;
        _authURL = SPAuthURL;
        
#if TARGET_OS_IPHONE
        [SPKeychain setAccessibilityType:kSecAttrAccessibleAlways];
#endif
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kSPReachabilityChangedNotification object:nil];
        _reachability = [SPReachability reachabilityForInternetConnection];
        _connected = self.reachability.currentReachabilityStatus != NotReachable;
        [_reachability startNotifier];
    }
    return self;
}

- (void)handleNetworkChange:(NSNotification *)notification {
    self.connected = (self.reachability.currentReachabilityStatus != NotReachable);
}

// Open a UI to handle authentication if necessary
- (BOOL)authenticateIfNecessary {
    
    NSAssert(self.simperium.APIKey, @"Simperium APIKey must be initialized before attempting authentication");
    NSAssert(self.simperium.appID, @"Simperium AppID must be initialized before attempting authentication");
    
    // Look up a stored token (if it exists) and try authenticating
    NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:SPUsername];
    NSString *token = nil;
    
    if (username) {
        NSError *error = nil;
        token = [SPKeychain passwordForService:self.simperium.appID account:username error:&error];
        
        if (error) {
            SPLogError(@"Simperium couldn't retrieve token from keychain. Error: %@", error);
        }
    }
    
    if (!username || username.length == 0 || !token || token.length == 0) {
        SPLogInfo(@"Simperium didn't find an existing auth token (username %@; token %@; appID: %@)", username, token, self.simperium.appID);
        if ([self.delegate respondsToSelector:@selector(authenticationDidFail)]) {
            [self.delegate authenticationDidFail];
        }
        
        return YES;
    }
    
    SPLogInfo(@"Simperium found an existing auth token for %@", username);
    // Assume the token is valid and return success
    // TODO: ensure if it isn't valid, a reauth process will get triggered

    // Set the Simperium user
    self.simperium.user = [[SPUser alloc] initWithEmail:username token:token];

    if ([self.delegate respondsToSelector:@selector(authenticationDidSucceedForUsername:token:)]) {
        [self.delegate authenticationDidSucceedForUsername:username token:token];
    }
    
    return NO;
}


#pragma mark - Authentication

- (void)authenticateWithUsername:(NSString *)username
                           token:(NSString *)token {
    NSParameterAssert(username);
    NSParameterAssert(token);

    SPUser *user = [[SPUser alloc] initWithEmail:username token:token];
    self.simperium.user = user;

    [self saveCredentialsForUser:user];
    [self notifySignupDidSucceed];
    [self notifyAuthenticationDidSucceed];
}

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                         success:(SuccessBlockType)successHandler
                         failure:(FailureBlockType)failureHandler {
    NSParameterAssert(username);
    NSParameterAssert(password);
    NSParameterAssert(successHandler);
    NSParameterAssert(failureHandler);

    NSURLRequest *request = [NSURLRequest sp_loginRequestWithBaseURL:self.authURL
                                                   customHTTPHeaders:self.customHTTPHeaders
                                                               appID:self.simperium.appID
                                                              apiKey:self.simperium.APIKey
                                                            provider:self.providerString
                                                            username:username
                                                            password:password];
    SPLogInfo(@"Simperium Authenticating: %@", request.URL);

    [[NSURLSession sharedSession] performURLRequest:request completionHandler:^(NSInteger statusCode, NSString * _Nullable responseString, NSError * _Nullable error) {
        BOOL success = [self processAuthenticationResponse:responseString statusCode:statusCode];
        if (!success) {
            SPLogError(@"Simperium authentication error (%d): %@", statusCode, error);
            failureHandler(statusCode, responseString, error);
            [self notifyAuthenticationDidFail];
            return;
        }

        SPLogInfo(@"Simperium authentication success!");
        successHandler();
        [self notifyAuthenticationDidSucceed];
    }];
}


#pragma mark - Validation

- (void)validateWithUsername:(NSString *)username
                    password:(NSString *)password
                     success:(SuccessBlockType)successHandler
                     failure:(FailureBlockType)failureHandler {
    NSParameterAssert(username);
    NSParameterAssert(password);
    NSParameterAssert(successHandler);
    NSParameterAssert(failureHandler);

    NSURLRequest *request = [NSURLRequest sp_loginRequestWithBaseURL:self.authURL
                                                   customHTTPHeaders:self.customHTTPHeaders
                                                               appID:self.simperium.appID
                                                              apiKey:self.simperium.APIKey
                                                            provider:self.providerString
                                                            username:username
                                                            password:password];
    SPLogInfo(@"Simperium Validating Credentials: %@", request.URL);

    [[NSURLSession sharedSession] performURLRequest:request completionHandler:^(NSInteger statusCode, NSString * _Nullable responseString, NSError * _Nullable error) {
        SPUser *user = [SPUser parseUserFromResponseString:responseString];
        if (user.authenticated == NO) {
            SPLogError(@"Simperium account validation error (%d): %@", statusCode, error);
            failureHandler(statusCode, responseString, error);
            return;
        }

        SPLogInfo(@"Simperium account validated!");
        successHandler();
    }];
}


#pragma mark - Signup

- (void)signupWithUsername:(NSString *)username
                  password:(NSString *)password
                   success:(SuccessBlockType)successHandler
                   failure:(FailureBlockType)failureHandler {
    NSParameterAssert(username);
    NSParameterAssert(password);
    NSParameterAssert(successHandler);
    NSParameterAssert(failureHandler);

    NSURLRequest *request = [NSURLRequest sp_signupRequestWithBaseURL:self.authURL
                                                    customHTTPHeaders:self.customHTTPHeaders
                                                                appID:self.simperium.appID
                                                               apiKey:self.simperium.APIKey
                                                             provider:self.providerString
                                                             username:username
                                                             password:password];
    SPLogInfo(@"Simperium Signup: %@", request.URL);

    [[NSURLSession sharedSession] performURLRequest:request completionHandler:^(NSInteger statusCode, NSString * _Nullable responseString, NSError * _Nullable error) {
        BOOL success = [self processAuthenticationResponse:responseString statusCode:statusCode];
        if (!success) {
            SPLogError(@"Simperium signup error (%d): %@", statusCode, error);
            failureHandler(statusCode, responseString, error);
            [self notifyAuthenticationDidFail];
            return;
        }

        SPLogInfo(@"Simperium signup success!");
        successHandler();
        [self notifySignupDidSucceed];
        [self notifyAuthenticationDidSucceed];
    }];
}


#pragma mark - Response Parsing

- (BOOL)processAuthenticationResponse:(NSString *)responseString statusCode:(NSInteger)statusCode {
    if (statusCode >= 400) {
        return NO;
    }

    SPUser *user = [SPUser parseUserFromResponseString:responseString];
    if (!user) {
        return NO;
    }

    [self saveCredentialsForUser:user];
    self.simperium.user = user;

    return YES;
}


#pragma mark - Keychain Helpers

- (void)saveCredentialsForUser:(SPUser *)user {
    [[NSUserDefaults standardUserDefaults] setObject:user.email forKey:SPUsername];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSError *error = nil;
    if ([SPKeychain setPassword:user.authToken forService:self.simperium.appID account:user.email error:&error]) {
        return;
    }

    SPLogError(@"Simperium couldn't store token in the keychain. Error: %@", error);
}


#pragma mark - Delegate Wrappers

- (void)notifyAuthenticationDidSucceed {
    if ([self.delegate respondsToSelector:@selector(authenticationDidSucceedForUsername:token:)]) {
        [self.delegate authenticationDidSucceedForUsername:self.simperium.user.email token:self.simperium.user.authToken];
    }
}

- (void)notifyAuthenticationDidFail {
    if ([self.delegate respondsToSelector:@selector(authenticationDidFail)]) {
        [self.delegate authenticationDidFail];
    }
}

- (void)notifySignupDidSucceed {
    if ([self.delegate respondsToSelector:@selector(authenticationDidCreateAccount)]) {
        [self.delegate authenticationDidCreateAccount];
    }
}


#pragma mark - Public API(s)

- (void)reset {
    SPLogVerbose(@"Simperium Authenticator resetting credentials");
    
    NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:SPUsername];
    if (!username || username.length == 0) {
        username = self.simperium.user.email;
    }
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SPUsername];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (username && username.length > 0) {
        [SPKeychain deletePasswordForService:self.simperium.appID account:username error:nil];
    }
}

- (void)cancel {
    SPLogVerbose(@"Simperium authentication cancelled");
    
    if ([self.delegate respondsToSelector:@selector(authenticationDidCancel)]) {
        [self.delegate authenticationDidCancel];
    }
}

@end
