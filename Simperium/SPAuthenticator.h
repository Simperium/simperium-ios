//
//  SPAuthenticator.h
//  Simperium
//
//  Created by Michael Johnston on 12-02-27.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


@class Simperium;


#pragma mark - SPAuthenticatorPolicy

typedef enum SPAuthenticatorPolicy : NSInteger {
    SPAuthenticatorPolicyAllow,
    SPAuthenticatorPolicyCancel
} SPAuthenticatorPolicy;


#pragma mark - SPAuthenticatorDelegate

@protocol SPAuthenticatorDelegate <NSObject>
@optional
- (void)authenticationDidSucceedForUsername:(NSString *)username token:(NSString *)token;
- (void)authenticationDidCreateAccount;
- (void)authenticationDidFail;
- (void)authenticationDidCancel;
@end


#pragma mark - Block Types

typedef void(^FailedBlockType)(NSInteger responseCode, NSString *responseString);
typedef void(^SucceededBlockType)(void);
typedef void(^DecisionHandlerBlockType)(NSInteger responseCode, void (^)(SPAuthenticatorPolicy));


#pragma mark - SPAuthenticator

@interface SPAuthenticator : NSObject

@property (nonatomic, copy,   readwrite) NSString   *providerString;
@property (nonatomic, assign,  readonly) BOOL       connected;

- (instancetype)initWithDelegate:(id<SPAuthenticatorDelegate>)authDelegate simperium:(Simperium *)s;

- (BOOL)authenticateIfNecessary;

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                         success:(SucceededBlockType)successBlock
                         failure:(FailedBlockType)failureBlock;

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                 decisionHandler:(DecisionHandlerBlockType)decisionBlock
                         success:(SucceededBlockType)successBlock
                         failure:(FailedBlockType)failureBlock;

- (void)createWithUsername:(NSString *)username
                  password:(NSString *)password
                   success:(SucceededBlockType)successBlock
                   failure:(FailedBlockType)failureBlock;
- (void)reset;
- (void)cancel;

+ (BOOL)needsAuthenticationForAppWithID:(NSString *)appID;

@end
