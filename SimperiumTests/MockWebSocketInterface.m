//
//  MockWebsocketInterface.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 11/11/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "MockWebSocketInterface.h"
#import "MockWebSocket.h"


@interface SPWebSocketInterface() <SRWebSocketDelegate>
@property (nonatomic, strong, readwrite) SRWebSocket *webSocket;
@end


@implementation MockWebSocketInterface

+(void)initialize
{
	NSAssert([SPWebSocketInterface respondsToSelector:@selector(registerClass:)], nil);
	[SPWebSocketInterface performSelector:@selector(registerClass:) withObject:[self class]];
}

-(void)openWebSocket {
    MockWebSocket *newWebSocket = [[MockWebSocket alloc] init];
    self.webSocket = newWebSocket;
    self.webSocket.delegate = self;
}

@end
