//
//  SPWebSocket.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 1/10/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPRWebSocket.h"



@class SPWebSocket;

#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

typedef enum {
    SPWebSocketErrorsActivityTimeout = -42
} SPWebSocketErrors;


#pragma mark ====================================================================================
#pragma mark SPWebSocketDelegate
#pragma mark ====================================================================================

@protocol SPWebSocketDelegate <NSObject>
- (void)webSocket:(SPWebSocket *)webSocket didReceiveMessage:(id)message;
- (void)webSocketDidOpen:(SPWebSocket *)webSocket;
- (void)webSocket:(SPWebSocket *)webSocket didFailWithError:(NSError *)error;
- (void)webSocket:(SPWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
@end


#pragma mark ====================================================================================
#pragma mark Simperium WebSocket Adapter
#pragma mark ====================================================================================

@interface SPWebSocket : NSObject

@property (nonatomic, assign, readwrite) NSTimeInterval             activityTimeout;
@property (nonatomic, weak,   readwrite) id<SPWebSocketDelegate>    delegate;
@property (nonatomic, assign,  readonly) SPRReadyState               readyState;
@property (nonatomic, strong,  readonly) NSDate                     *lastSeenTimestamp;
@property (nonatomic, assign,  readonly) NSUInteger                 bytesSent;
@property (nonatomic, assign,  readonly) NSUInteger                 bytesReceived;

- (instancetype)initWithURLRequest:(NSURLRequest *)request;

- (void)open;
- (void)close;
- (void)send:(id)data;

@end
