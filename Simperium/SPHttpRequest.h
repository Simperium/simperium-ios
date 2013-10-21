//
//  SPHttpRequest.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/21/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


#pragma mark ====================================================================================
#pragma mark SPHttpRequestDelegate
#pragma mark ====================================================================================

@class SPHttpRequest;

typedef NS_ENUM(NSUInteger, SPHttpRequestMethods) {
	SPHttpRequestMethodsPost,
    SPHttpRequestMethodsGet
};

typedef NS_ENUM(NSUInteger, SPHttpRequestErrors) {
	SPHttpRequestErrorsTimeout
};

@protocol SPHttpRequestDelegate <NSObject>
-(void)httpRequestStarted:(SPHttpRequest *)request;
-(void)httpRequestSuccessful:(SPHttpRequest *)request data:(NSData*)data;
-(void)httpRequestFailed:(SPHttpRequest *)request error:(NSError *)error;
-(void)httpRequestProgress:(SPHttpRequest *)request increment:(long long)increment;
@end


#pragma mark ====================================================================================
#pragma mark SPHttpRequest
#pragma mark ====================================================================================

@interface SPHttpRequest : NSObject

@property (nonatomic, strong, readonly)  NSURL *url;
@property (nonatomic, strong, readonly)  NSDictionary *headers;
@property (nonatomic, strong, readonly)  NSDictionary *userInfo;
@property (nonatomic, weak,   readwrite) id<SPHttpRequestDelegate> delegate;

+(SPHttpRequest *)requestWithURL:(NSURL*)url
						 headers:(NSDictionary*)headers
						userInfo:(NSDictionary *)userInfo
						  method:(SPHttpRequestMethods)method
						delegate:(id<SPHttpRequestDelegate>)delegate;
@end
