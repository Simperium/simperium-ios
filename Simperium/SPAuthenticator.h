//
//  SPAuthenticator.h
//  Simperium
//
//  Created by Michael Johnston on 12-02-27.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void(^SucceededBlockType)(void);
typedef void(^FailedBlockType)(int responseCode, NSString *responseString);

@class Simperium;


#pragma mark ====================================================================================
#pragma mark SPAuthenticatorLoginResponsePolicy
#pragma mark ====================================================================================

typedef enum SPAuthenticatorLoginResponsePolicy : NSInteger {
    SPAuthenticatorLoginResponsePolicyAllow,
    SPAuthenticatorLoginResponsePolicyCancel
} SPAuthenticatorLoginResponsePolicy;


#pragma mark ====================================================================================
#pragma mark SPAuthenticatorDelegate
#pragma mark ====================================================================================

@protocol SPAuthenticatorDelegate <NSObject>
@optional
- (SPAuthenticatorLoginResponsePolicy)authenticationDecidePolicyForLoginResponseCode:(NSInteger)responseCode;
- (void)authenticationDidSucceedForUsername:(NSString *)username token:(NSString *)token;
- (void)authenticationDidCreateAccount;
- (void)authenticationDidFail;
- (void)authenticationDidCancel;
@end


#pragma mark ====================================================================================
#pragma mark SPAuthenticator
#pragma mark ====================================================================================

@interface SPAuthenticator : NSObject

@property (nonatomic, copy,   readwrite) NSString   *providerString;
@property (nonatomic, assign,  readonly) BOOL       connected;

- (instancetype)initWithDelegate:(id<SPAuthenticatorDelegate>)authDelegate simperium:(Simperium *)s;
- (BOOL)authenticateIfNecessary;
- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password success:(SucceededBlockType)successBlock failure:(FailedBlockType)failureBlock;
- (void)createWithUsername:(NSString *)username password:(NSString *)password success:(SucceededBlockType)successBlock failure:(FailedBlockType)failureBlock;
- (void)reset;
- (void)cancel;

+ (BOOL)needsAuthenticationForAppWithID:(NSString *)appID;

@end
