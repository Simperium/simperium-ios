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


#pragma mark ====================================================================================
#pragma mark SPHttpRequest
#pragma mark ====================================================================================

@interface SPHttpRequest : NSObject

@property (nonatomic, strong, readonly)  NSURL *url;
@property (nonatomic, strong, readonly)  NSData* response;
@property (nonatomic, strong, readonly)  NSError* error;

@property (nonatomic, strong, readwrite) NSDictionary *headers;
@property (nonatomic, strong, readwrite) NSDictionary *userInfo;

@property (nonatomic, weak,   readwrite) id delegate;
@property (nonatomic, assign, readwrite) SEL selectorStarted;
@property (nonatomic, assign, readwrite) SEL selectorSuccess;
@property (nonatomic, assign, readwrite) SEL selectorFailed;
@property (nonatomic, assign, readwrite) SEL selectorProgress;

+(SPHttpRequest *)requestWithURL:(NSURL*)url method:(SPHttpRequestMethods)method;

@end
