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
#import "SPBinaryManager.h"
#import "DDLog.h"
#import "JSONKit+Simperium.h"
#import "SFHFKeychainUtils.h"
#import "SPReachability.h"
#import "SPHttpRequest.h"
#import "SPHttpRequestQueue.h"

#define USERNAME_KEY @"SPUsername"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h> // for UIDevice
#else
#import <AppKit/NSApplication.h>
#endif

static int ddLogLevel = LOG_LEVEL_INFO;

@interface SPAuthenticator()
@property (nonatomic, strong, readwrite) SPReachability	*reachability;
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
        
        self.reachability = [SPReachability reachabilityForInternetConnection];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
        self.connected = [self.reachability currentReachabilityStatus] != NotReachable;
        [self.reachability startNotifier];

    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleNetworkChange:(NSNotification *)notification {
    if ([self.reachability currentReachabilityStatus] == NotReachable) {
        self.connected = NO;
    } else {
        self.connected = YES;
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
    username = [username lowercaseString];
    NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/authorize/", SPAuthURL, simperium.appID]];
    DDLogInfo(@"Simperium authenticating: %@", [NSString stringWithFormat:@"%@%@/authorize/", SPAuthURL, simperium.appID]);
    DDLogVerbose(@"Simperium username is %@", username);

    SPHttpRequest *request = [SPHttpRequest requestWithURL:tokenURL];
	request.headers = @{
		@"X-Simperium-API-Key"	: simperium.APIKey,
		@"Content-Type"			: @"application/json"
	};
	
    NSDictionary *authDict = @{
		@"username" : username,
		@"password" : password
	};

	request.method = SPHttpRequestMethodsPost;
	request.postData = [[authDict sp_JSONString] dataUsingEncoding:NSUTF8StringEncoding];
	request.delegate = self;
	request.selectorSuccess	= @selector(authDidSucceed:);
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
		
		// Cleanup!
		self.failedBlock = nil;
		self.succeededBlock = nil;
	}
    
    DDLogInfo(@"Simperium authentication success!");

    if ([delegate respondsToSelector:@selector(authenticationDidSucceedForUsername:token:)])
        [delegate authenticationDidSucceedForUsername:simperium.user.email token:simperium.user.authToken];
}

- (void)authDidSucceed:(SPHttpRequest *)request {
    NSString *tokenResponse = request.responseString;
    if (request.responseCode != 200) {
        [self authDidFail:request];
        return;
    }
    
    NSDictionary *userDict = [tokenResponse sp_objectFromJSONString];
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

- (void)authDidFail:(SPHttpRequest *)request {
    if (self.failedBlock) {
        self.failedBlock(request.responseCode, request.responseString);
		
		// Cleanup!
		self.failedBlock = nil;
		self.succeededBlock = nil;
	}
    
    DDLogError(@"Simperium authentication error (%d): %@", request.responseCode, request.responseError);
    
    if ([delegate respondsToSelector:@selector(authenticationDidFail)])
        [delegate authenticationDidFail];
}

- (void)createWithUsername:(NSString *)username password:(NSString *)password success:(SucceededBlockType)successBlock failure:(FailedBlockType)failureBlock {
    NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/create/", SPAuthURL, simperium.appID]];
    
    SPHttpRequest *request = [SPHttpRequest requestWithURL:tokenURL];
    NSMutableDictionary *authData = [@{
		@"username" : username,
		@"password" : password,
	} mutableCopy];
    
    // Backend authentication may need extra data
    if ([providerString length] > 0) {
        [authData setObject:providerString forKey:@"provider"];
	}
    
	request.method = SPHttpRequestMethodsPost;
	request.postData = [[authData sp_JSONString] dataUsingEncoding:NSUTF8StringEncoding];
	request.headers = @{
		@"Content-Type"			: @"application/json",
		@"X-Simperium-API-Key"	: simperium.APIKey
	};

    // Blocks are used here for UI tasks on iOS/OSX
    self.succeededBlock = successBlock;
    self.failedBlock = failureBlock;
    
    // Selectors are for auth-related handling
    request.delegate = self;
	request.selectorSuccess = @selector(authDidSucceed:);
	request.selectorFailed = @selector(authDidFail:);

	[[SPHttpRequestQueue sharedInstance] enqueueHttpRequest:request];
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
