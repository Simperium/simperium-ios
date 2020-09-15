//
//  SPAuthenticator.h
//  Simperium
//
//  Created by Michael Johnston on 12-02-27.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void(^SuccessBlockType)(void);
typedef void(^FailureBlockType)(NSInteger responseCode, NSString *responseString, NSError *error);

@class Simperium;


#pragma mark ====================================================================================
#pragma mark SPAuthenticatorDelegate
#pragma mark ====================================================================================

@protocol SPAuthenticatorDelegate <NSObject>
@optional
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

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                         success:(SuccessBlockType)successHandler
                         failure:(FailureBlockType)failureHandler;

- (void)validateWithUsername:(NSString *)username
                    password:(NSString *)password
                     success:(SuccessBlockType)successHandler
                     failure:(FailureBlockType)failureHandler;

- (void)signupWithUsername:(NSString *)username
                  password:(NSString *)password
                   success:(SuccessBlockType)successHandler
                   failure:(FailureBlockType)failureHandler;

- (void)reset;
- (void)cancel;

@end
