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
@class SPWebSocketInterface;
@protocol SPDiffable;

@interface SPWebSocketChannel : NSObject
{
    BOOL indexing;
    BOOL started;
    BOOL retrievingObjectHistory;
    int retryDelay;
    NSString *nextMark;
    NSMutableArray *indexArray;
    NSString *pendingLastChangeSignature;
    SPWebSocketInterface *__weak webSocketManager;
    NSString *name;
    int number;
    NSInteger objectVersionsPending;
}

@property (nonatomic, weak) SPWebSocketInterface *webSocketManager;
@property (nonatomic, copy) NSString *nextMark;
@property (nonatomic, strong) NSMutableArray *indexArray;
@property (nonatomic, copy) NSString *pendingLastChangeSignature;
@property (nonatomic) int number;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) BOOL started;

+ (void)setNetworkActivityIndicatorEnabled:(BOOL)enabled;
- (id)initWithSimperium:(Simperium *)s clientID:(NSString *)cid;
- (void)requestVersions:(int)numVersions object:(id<SPDiffable>)object;
- (void)requestLatestVersionsForBucket:(SPBucket *)bucket;
- (void)sendObjectDeletion:(id<SPDiffable>)object;
- (void)sendObjectChanges:(id<SPDiffable>)object;
- (void)shareObject:(id<SPDiffable>)object withEmail:(NSString *)email;
- (void)handleRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket;
- (void)handleIndexResponse:(NSString *)responseString bucket:(SPBucket *)bucket;
- (void)handleVersionResponse:(NSString *)responseString bucket:(SPBucket *)bucket;
- (void)startProcessingChangesForBucket:(SPBucket *)bucket;

@end
