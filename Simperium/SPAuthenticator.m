//
//  SPAuthenticator.m
//  Simperium
//
//  Created by Michael Johnston on 12-02-27.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "Simperium.h"
#import "SPEnvironment.h"
#import "SPUser.h"
#import "SPAuthenticator.h"
#import "ASIFormDataRequest.h"
#import "ASIHTTPRequest.h"
#import "DDLog.h"
#import "JSONKit.h"
#import "SFHFKeychainUtils.h"
#import "SPReachability.h"

#define USERNAME_KEY @"SPUsername"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h> // for UIDevice
#else
#import <AppKit/NSApplication.h>
#endif

static int ddLogLevel = LOG_LEVEL_INFO;

@interface SPAuthenticator() {
    SPReachability *reachability;
}

-(void)authDidFail:(ASIHTTPRequest *)request;
@end

@implementation SPAuthenticator
@synthesize succeededBlock;
@synthesize failedBlock;
@synthesize simperium;
@synthesize connected;
@synthesize providerString;

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

- (id)initWithDelegate:(id<SPAuthenticatorDelegate>)authDelegate simperium:(Simperium *)s {
    if ((self = [super init])) {
        delegate = authDelegate;
        simperium = s;
        
        reachability = [SPReachability reachabilityForInternetConnection];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
        connected = [reachability currentReachabilityStatus] != NotReachable;
        [reachability startNotifier];

    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleNetworkChange:(NSNotification *)notification {
    if ([reachability currentReachabilityStatus] == NotReachable) {
        connected = NO;
    } else {
        connected = YES;
    }
}

// Open a UI to handle authentication if necessary
- (BOOL)authenticateIfNecessary {
    // Look up a stored token (if it exists) and try authenticating
    NSString *username = nil, *token = nil;
    username = [[NSUserDefaults standardUserDefaults] objectForKey:USERNAME_KEY];
    
    if (username)
        token = [SFHFKeychainUtils getPasswordForUsername:username andServiceName:simperium.appID error:nil];
    
    if (!username || username.length == 0 || !token || token.length == 0) {
        DDLogInfo(@"Simperium didn't find an existing auth token (username %@; token %@; appID: %@)", username, token, simperium.appID);
        if ([delegate respondsToSelector:@selector(authenticationDidFail)])
            [delegate authenticationDidFail];
        
        return YES;
    } else {
         DDLogInfo(@"Simperium found an existing auth token for %@", username);
        // Assume the token is valid and return success
        // TODO: ensure if it isn't valid, a reauth process will get triggered

        // Set the Simperium user
        SPUser *aUser = [[SPUser alloc] initWithEmail:username token:token];
        simperium.user = aUser;

        if ([delegate respondsToSelector:@selector(authenticationDidSucceedForUsername:token:)])
            [delegate authenticationDidSucceedForUsername:username token:token];
    }
    return NO;
}

// Perform the actual authentication calls to Simperium
- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password success:(SucceededBlockType)successBlock failure:(FailedBlockType)failureBlock
{    
    NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/authorize/", SPAuthURL, simperium.appID]];
    DDLogInfo(@"Simperium authenticating: %@", [NSString stringWithFormat:@"%@%@/authorize/", SPAuthURL, simperium.appID]);
    DDLogVerbose(@"Simperium username is %@", username);
    
    ASIFormDataRequest *tokenRequest = [[ASIFormDataRequest alloc] initWithURL:tokenURL];
    NSDictionary *authData = [NSDictionary dictionaryWithObjectsAndKeys:
                              username, @"username",
                              password, @"password", nil];
    NSString *jsonData = [authData JSONString];
    [tokenRequest appendPostData:[jsonData dataUsingEncoding:NSUTF8StringEncoding]];
    [tokenRequest addRequestHeader:@"Content-Type" value:@"application/json"];
    [tokenRequest addRequestHeader:@"X-Simperium-API-Key" value:simperium.APIKey];
    [tokenRequest setTimeOutSeconds:8];
    [tokenRequest setDelegate:self];
    
    // Blocks are used here for UI tasks on iOS/OSX
    self.succeededBlock = successBlock;
    self.failedBlock = failureBlock;
    
    // Selectors are for auth-related handling
    [tokenRequest setDidFinishSelector:@selector(authDidSucceed:)];
    [tokenRequest setDidFailSelector:@selector(authDidFail:)];
    [tokenRequest startAsynchronous];
}

- (void)delayedAuthenticationDidFinish {
    if (self.succeededBlock) {
        self.succeededBlock();
		
		// Cleanup!
		self.failedBlock = nil;
		self.succeededBlock = nil;
	}
    
    DDLogInfo(@"Simperium authentication success!");

    if ([delegate respondsToSelector:@selector(authenticationDidSucceedForUsername:token:)])
        [delegate authenticationDidSucceedForUsername:simperium.user.email token:simperium.user.authToken];
}

- (void)authDidSucceed:(ASIHTTPRequest *)request {
    NSString *tokenResponse = [request responseString];
    int code = [request responseStatusCode];
    if (code != 200) {
        [self authDidFail:request];
        return;
    }
    
    NSDictionary *userDict = [tokenResponse objectFromJSONString];
    NSString *username = [userDict objectForKey:@"username"];
    NSString *token = [userDict objectForKey:@"access_token"];
    
    // Set the user's details
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:USERNAME_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [SFHFKeychainUtils storeUsername:username andPassword:token forServiceName:simperium.appID updateExisting:YES error:nil];
    
    // Set the Simperium user
    SPUser *aUser = [[SPUser alloc] initWithEmail:username token:token];
    simperium.user = aUser;
    
    [self performSelector:@selector(delayedAuthenticationDidFinish) withObject:nil afterDelay:0.1];
}

- (void)authDidFail:(ASIHTTPRequest *)request {
    if (self.failedBlock) {
        self.failedBlock([request responseStatusCode], [request responseString]);
		
		// Cleanup!
		self.failedBlock = nil;
		self.succeededBlock = nil;
	}
    
    DDLogError(@"Simperium authentication error (%d): %@",[request responseStatusCode], [request responseString]);
    
    if ([delegate respondsToSelector:@selector(authenticationDidFail)])
        [delegate authenticationDidFail];
}

- (void)createWithUsername:(NSString *)username password:(NSString *)password success:(SucceededBlockType)successBlock failure:(FailedBlockType)failureBlock {
    NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/create/", SPAuthURL, simperium.appID]];
    
    ASIFormDataRequest *tokenRequest = [[ASIFormDataRequest alloc] initWithURL:tokenURL];
    NSMutableDictionary *authData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              username, @"username",
                              password, @"password",
                              nil];
    
    // Backend authentication may need extra data
    if ([providerString length] > 0)
        [authData setObject:providerString forKey:@"provider"];
    
    NSString *jsonData = [authData JSONString];
    [tokenRequest appendPostData:[jsonData dataUsingEncoding:NSUTF8StringEncoding]];
    [tokenRequest addRequestHeader:@"Content-Type" value:@"application/json"];
    [tokenRequest addRequestHeader:@"X-Simperium-API-Key" value:simperium.APIKey];
    [tokenRequest setDelegate:self];
    
    // Blocks are used here for UI tasks on iOS/OSX
    self.succeededBlock = successBlock;
    self.failedBlock = failureBlock;
    
    // Selectors are for auth-related handling
    [tokenRequest setDidFinishSelector:@selector(authDidSucceed:)];
    [tokenRequest setDidFailSelector:@selector(authDidFail:)];
    [tokenRequest startAsynchronous];
}

- (void)reset {
    NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:USERNAME_KEY];
    if (!username || username.length == 0)
        username = simperium.user.email;
    
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:USERNAME_KEY];
    
    if (username && username.length > 0)
        [SFHFKeychainUtils deleteItemForUsername:simperium.user.email andServiceName:simperium.appID error:nil];
}

- (void)cancel {
    DDLogVerbose(@"Simperium authentication cancelled");
    
    if ([delegate respondsToSelector:@selector(authenticationDidCancel)])
        [delegate authenticationDidCancel];
}

@end
