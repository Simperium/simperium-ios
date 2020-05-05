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
#import "JSONKit+Simperium.h"
#import "SPKeychain.h"
#import "SPReachability.h"
#import "SPHttpRequest.h"
#import "SPHttpRequestQueue.h"
#import "SPLogger.h"


#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h> // for UIDevice
#else
#import <AppKit/NSApplication.h>
#endif



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
@property (nonatomic,   copy, readwrite) SucceededBlockType             succeededBlock;
@property (nonatomic,   copy, readwrite) FailedBlockType                failedBlock;
@property (nonatomic,   copy, readwrite) DecisionHandlerBlockType       decisionHandler;
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

// Perform the actual authentication calls to Simperium
- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                         success:(SucceededBlockType)successBlock
                         failure:(FailedBlockType)failureBlock
{
    [self authenticateWithUsername:username password:password decisionHandler:nil success:successBlock failure:failureBlock];
}

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                 decisionHandler:(DecisionHandlerBlockType)decisionBlock
                         success:(SucceededBlockType)successBlock
                         failure:(FailedBlockType)failureBlock
{
    NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/authorize/", SPAuthURL, self.simperium.appID]];
    SPLogInfo(@"Simperium authenticating: %@", [NSString stringWithFormat:@"%@%@/authorize/", SPAuthURL, self.simperium.appID]);
    SPLogVerbose(@"Simperium username is %@", username);
    
    SPHttpRequest *request = [SPHttpRequest requestWithURL:tokenURL];
    request.headers = @{
        @"X-Simperium-API-Key"  : self.simperium.APIKey,
        @"Content-Type"         : @"application/json"
    };
    
    NSDictionary *authDict = @{
        @"username" : username,
        @"password" : password
    };

    request.method = SPHttpRequestMethodsPost;
    request.postData = [[authDict sp_JSONString] dataUsingEncoding:NSUTF8StringEncoding];
    request.delegate = self;
    request.selectorSuccess = @selector(authDidSucceed:);
    request.selectorFailed = @selector(authDidFail:);
    request.timeout = 8;
    
    // Blocks are used here for UI tasks on iOS/OSX
    self.succeededBlock = successBlock;
    self.failedBlock = failureBlock;
    
    // Selectors are for auth-related handling
    [[SPHttpRequestQueue sharedInstance] enqueueHttpRequest:request];
}

- (void)delayedAuthenticationDidFinish {
    if (self.succeededBlock) {
        self.succeededBlock();
        [self resetCallbackBlocks];
    }
    
    SPLogInfo(@"Simperium authentication success!");

    if ([self.delegate respondsToSelector:@selector(authenticationDidSucceedForUsername:token:)]) {
        [self.delegate authenticationDidSucceedForUsername:self.simperium.user.email token:self.simperium.user.authToken];
    }
}

- (void)resetCallbackBlocks {
    self.failedBlock = nil;
    self.succeededBlock = nil;
    self.decisionHandler = nil;
}

- (void)authDidSucceed:(SPHttpRequest *)request {
    if (request.responseCode != 200) {
        [self authDidFail:request];
        return;
    }

    if (![self isAuthenticationAllowedWithResponseCode:request.responseCode]) {
        SPLogInfo(@"Simperium Auth Policy: DENY!");
        [self resetCallbackBlocks];
        return;
    }

    NSDictionary *userDict  = [request.responseString sp_objectFromJSONString];
    NSString *username      = userDict[@"username"];
    NSString *token         = userDict[@"access_token"];
    
    // Set the user's details
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:SPUsername];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSError *error = nil;
    BOOL success = [SPKeychain setPassword:token forService:self.simperium.appID account:username error:&error];
    
    if (success == NO) {
        SPLogError(@"Simperium couldn't store token in the keychain. Error: %@", error);
    }
    
    // Set the Simperium user
    self.simperium.user = [[SPUser alloc] initWithEmail:username token:token];
    
    [self performSelector:@selector(delayedAuthenticationDidFinish) withObject:nil afterDelay:0.1];
}

- (void)authWithCreationDidSucceed:(SPHttpRequest *)request {
    [self authDidSucceed:request];

    if ([self.delegate respondsToSelector:@selector(authenticationDidCreateAccount)]) {
        [self.delegate authenticationDidCreateAccount];
    }
}

- (void)authDidFail:(SPHttpRequest *)request {
    if (self.failedBlock) {
        self.failedBlock(request.responseCode, request.responseString);
        [self resetCallbackBlocks];
    }
    
    SPLogError(@"Simperium authentication error (%d): %@", request.responseCode, request.responseError);
    
    if ([self.delegate respondsToSelector:@selector(authenticationDidFail)]) {
        [self.delegate authenticationDidFail];
    }
}

- (void)createWithUsername:(NSString *)username password:(NSString *)password success:(SucceededBlockType)successBlock failure:(FailedBlockType)failureBlock {
    NSAssert(self.simperium.APIKey, @"Simperium Error: attempted user creation with no APIKey");
    
    if (!self.simperium.APIKey) {
        SPLogError(@"Simperium Error: attempted user creation with no APIKey");
        return;
    }
    
    NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/create/", SPAuthURL, self.simperium.appID]];
    
    SPHttpRequest *request = [SPHttpRequest requestWithURL:tokenURL];
    NSMutableDictionary *authData = [@{
        @"username" : username,
        @"password" : password
    } mutableCopy];
    
    // Backend authentication may need extra data
    if (self.providerString.length > 0) {
        [authData setObject:self.providerString forKey:@"provider"];
    }
    
    request.method = SPHttpRequestMethodsPost;
    request.postData = [[authData sp_JSONString] dataUsingEncoding:NSUTF8StringEncoding];
    request.headers = @{
        @"Content-Type"         : @"application/json",
        @"X-Simperium-API-Key"  : self.simperium.APIKey
    };
    
    // Blocks are used here for UI tasks on iOS/OSX
    self.succeededBlock = successBlock;
    self.failedBlock = failureBlock;
    
    // Selectors are for auth-related handling
    request.delegate = self;
    request.selectorSuccess = @selector(authWithCreationDidSucceed:);
    request.selectorFailed = @selector(authDidFail:);

    [[SPHttpRequestQueue sharedInstance] enqueueHttpRequest:request];
}

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


#pragma mark - Login Policy Helpers

- (BOOL)isAuthenticationAllowedWithResponseCode:(NSInteger)responseCode {

    if (self.decisionHandler == nil) {
        return YES;
    }

    __block BOOL isAllowed = YES;
    self.decisionHandler(responseCode, ^(SPAuthenticatorPolicy policy) {
        isAllowed = (policy == SPAuthenticatorPolicyAllow);
    });

    self.decisionHandler = nil;

    return isAllowed;
}


#pragma mark - Static Helpers

+ (BOOL)needsAuthenticationForAppWithID:(NSString *)appID {
    NSString *username  = [[NSUserDefaults standardUserDefaults] objectForKey:SPUsername];
    NSString *token     = nil;
    
    if (username) {
        token = [SPKeychain passwordForService:appID account:username error:nil];
    }
    
    return (username.length == 0 || token.length == 0);
}

@end
