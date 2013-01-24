//
//  SPHttpManager.h
//  Simperium
//
//  Created by Michael Johnston on 11-03-07.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPNetworkProvider.h"

@class Simperium;
@class ASIHTTPRequest;
@class SPBucket;

@interface SPHttpManager : NSObject <SPNetworkProvider> {
    SPBucket *bucket;
	ASIHTTPRequest *getRequest;
	ASIHTTPRequest *postRequest;
    BOOL requestCancelled;
    BOOL gettingVersions;
    BOOL started;
    int retryDelay;
    NSString *nextMark;
    NSMutableArray *indexArray;
    NSString *pendingLastChangeSignature;
}

@property (nonatomic, copy) NSString *nextMark;
@property (nonatomic, retain) NSMutableArray *indexArray;
@property(nonatomic, copy) NSString *pendingLastChangeSignature;

+(void)setNetworkActivityIndicatorEnabled:(BOOL)enabled;
-(id)initWithSimperium:(Simperium *)s appURL:(NSString *)url clientID:(NSString *)cid;
-(void)setBucket:(SPBucket *)aBucket overrides:(NSDictionary *)overrides;

@end