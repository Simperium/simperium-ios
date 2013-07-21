//
//  SPWebSocketManager
//  Simperium
//
//  Created by Michael Johnston on 12-08-06.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPNetworkInterface.h"

@class Simperium;
@class SPBucket;
@class SRWebSocket;
@class SRWebSocketChannel;

@interface SPWebSocketInterface : NSObject <SPNetworkInterface> {
    BOOL open;
    NSMutableArray *webSocketChannels;
    SRWebSocket *webSocket;
    NSTimer *heartbeatTimer;
}

@property (nonatomic, strong) SRWebSocket *webSocket;

- (id)initWithSimperium:(Simperium *)s appURL:(NSString *)url clientID:(NSString *)cid;
- (void)loadChannelsForBuckets:(NSDictionary *)bucketList overrides:(NSDictionary *)overrides;
- (void)send:(NSString *)message;

@end