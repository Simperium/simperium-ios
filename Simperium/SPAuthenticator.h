//
//  SPAuthenticator.h
//  Simperium
//
//  Created by Michael Johnston on 12-02-27.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void(^SuccessBlockType)(void);
typedef void(^FailureBlockType)(NSInteger responseCode, NSString * _Nullable responseString, NSError * _Nullable error);

@class Simperium;


NS_ASSUME_NONNULL_BEGIN

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

@property (nonatomic, copy,   readwrite) NSString       *baseURL;
@property (nonatomic, copy,   readwrite) NSDictionary   *customHTTPHeaders;
@property (nonatomic, copy,   readwrite) NSString       *providerString;
@property (nonatomic, assign,  readonly) BOOL           connected;

- (instancetype)initWithDelegate:(id<SPAuthenticatorDelegate>)authDelegate simperium:(Simperium *)s;

- (BOOL)authenticateIfNecessary;

- (void)authenticateWithUsername:(NSString *)username
                           token:(NSString *)token;

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

NS_ASSUME_NONNULL_END
