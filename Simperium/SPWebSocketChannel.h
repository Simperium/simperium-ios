//
//  SPWebSocketChannel.h
//  Simperium
//
//  Created by Michael Johnston on 12-08-09.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Simperium;
@class SPBucket;
@class SRWebSocket;
@protocol SPDiffable;

@interface SPWebSocketChannel : NSObject
{
    BOOL gettingVersions;
    BOOL started;
    int retryDelay;
    NSString *nextMark;
    NSMutableArray *indexArray;
    NSString *pendingLastChangeSignature;
    SRWebSocket *webSocket;
    NSString *name;
    int number;
    NSInteger numTransfers;
}

@property (nonatomic, assign) SRWebSocket *webSocket;
@property (nonatomic, copy) NSString *nextMark;
@property (nonatomic, retain) NSMutableArray *indexArray;
@property (nonatomic, copy) NSString *pendingLastChangeSignature;
@property (nonatomic) int number;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) BOOL started;

+(void)setNetworkActivityIndicatorEnabled:(BOOL)enabled;
-(id)initWithSimperium:(Simperium *)s clientID:(NSString *)cid;
-(void)getVersions:(int)numVersions forObject:(id<SPDiffable>)object;
-(void)getLatestVersionsForBucket:(SPBucket *)bucket;
-(void)sendObjectDeletion:(id<SPDiffable>)object;
-(void)sendObjectChanges:(id<SPDiffable>)object;
-(void)shareObject:(id<SPDiffable>)object withEmail:(NSString *)email;
-(void)handleRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket;
-(void)handleIndexResponse:(NSString *)responseString bucket:(SPBucket *)bucket;
-(void)handleVersionResponse:(NSString *)responseString bucket:(SPBucket *)bucket;
-(void)startProcessingChangesForBucket:(SPBucket *)bucket;

@end
