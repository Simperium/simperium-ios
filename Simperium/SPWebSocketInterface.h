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
@class SRWebSocket;

@interface SPWebSocketInterface : NSObject <SPNetworkInterface>

@property (nonatomic, strong, readonly) SRWebSocket *webSocket;

- (id)initWithSimperium:(Simperium *)s appURL:(NSString *)url clientID:(NSString *)cid;
- (void)loadChannelsForBuckets:(NSDictionary *)bucketList overrides:(NSDictionary *)overrides;
- (void)send:(NSString *)message;

@end
