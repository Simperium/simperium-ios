//
//  SPWebSocketManager
//  Simperium
//
//  Created by Michael Johnston on 11-03-07.
//  Copyright 2011 Simperium. All rights reserved.
//
#import "SPWebSocketInterface.h"
#import "Simperium.h"
#import "SPChangeProcessor.h"
#import "SPUser.h"
#import "SPBucket.h"
#import "JSONKit.h"
#import "NSString+Simperium.h"
#import "DDLog.h"
#import "DDLogDebug.h"
#import "SRWebSocket.h"
#import "SPWebSocketChannel.h"

#define WEBSOCKET_URL @"wss://api.simperium.com/sock/1"
#define INDEX_PAGE_SIZE 500
#define INDEX_BATCH_SIZE 10
#define HEARTBEAT 30

#if TARGET_OS_IPHONE
#define LIBRARY_ID @"ios"
#else
#define LIBRARY_ID @"osx"
#endif

#define LIBRARY_VERSION @0

NSString * const COM_AUTH = @"auth";
NSString * const COM_INDEX = @"i";
NSString * const COM_CHANGE = @"c";
NSString * const COM_ENTITY = @"e";
NSString * const COM_ERROR = @"?";

static int ddLogLevel = LOG_LEVEL_INFO;
NSString * const WebSocketAuthenticationDidFailNotification = @"AuthenticationDidFailNotification";

@interface SPWebSocketInterface() <SRWebSocketDelegate>
@property (nonatomic, weak) Simperium *simperium;
@property (nonatomic, strong) NSMutableDictionary *channels;
@property (nonatomic, copy) NSString *clientID;
@property (nonatomic, strong) NSDictionary *bucketNameOverrides;
@end

@implementation SPWebSocketInterface
@synthesize simperium;
@synthesize channels;
@synthesize clientID;
@synthesize webSocket;

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

- (id)initWithSimperium:(Simperium *)s appURL:(NSString *)url clientID:(NSString *)cid {
	if ((self = [super init])) {
        self.simperium = s;
        self.clientID = cid;
        self.channels = [NSMutableDictionary dictionaryWithCapacity:20];
	}
	
	return self;
}

- (SPWebSocketChannel *)channelForName:(NSString *)str {
    return [self.channels objectForKey:str];
}

- (SPWebSocketChannel *)channelForNumber:(NSNumber *)num {
    for (SPWebSocketChannel *channel in [self.channels allValues]) {
        if ([num intValue] == channel.number)
            return channel;
    }
    return nil;
}

- (SPWebSocketChannel *)loadChannelForBucket:(SPBucket *)bucket {
    int channelNumber = (int)[self.channels count];
    SPWebSocketChannel *channel = [[SPWebSocketChannel alloc] initWithSimperium:simperium clientID:clientID];
    channel.number = channelNumber;
    channel.name = bucket.name;
    [self.channels setObject:channel forKey:bucket.name];
    
    return [self.channels objectForKey:bucket.name];
}

- (void)loadChannelsForBuckets:(NSDictionary *)bucketList overrides:(NSDictionary *)overrides {
    self.bucketNameOverrides = overrides;
    
    for (SPBucket *bucket in [bucketList allValues])
        [self loadChannelForBucket:bucket];
}

- (void)sendObjectDeletion:(id<SPDiffable>)object {
    SPWebSocketChannel *channel = [self channelForName:object.bucket.name];
    [channel sendObjectDeletion:object];
}

- (void)sendObjectChanges:(id<SPDiffable>)object {
    SPWebSocketChannel *channel = [self channelForName:object.bucket.name];
    [channel sendObjectChanges:object];
}

- (void)authenticateChannel:(SPWebSocketChannel *)channel {
    //    NSString *message = @"1:command:parameters";
    NSString *remoteBucketName = [self.bucketNameOverrides objectForKey:channel.name];
    if (!remoteBucketName || remoteBucketName.length == 0)
        remoteBucketName = channel.name;
    
    NSDictionary *jsonData = @{
                               @"api" : @1,
                               @"clientid" : simperium.clientID,
                               @"app_id" : simperium.appID,
                               @"token" : simperium.user.authToken,
                               @"name" : remoteBucketName,
                               @"library" : LIBRARY_ID,
                               @"version" : LIBRARY_VERSION
                               };
    
    DDLogVerbose(@"Simperium initializing websocket channel %d:%@", channel.number, jsonData);
    NSString *message = [NSString stringWithFormat:@"%d:init:%@", channel.number, [jsonData JSONString]];
    [self.webSocket send:message];
}

- (void)openWebSocket {
    NSString *urlString = [NSString stringWithFormat:@"%@/%@/websocket", WEBSOCKET_URL, simperium.appID];
    SRWebSocket *newWebSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
    self.webSocket = newWebSocket;
    self.webSocket.delegate = self;
    
    DDLogVerbose(@"Simperium opening WebSocket connection...");
    [self.webSocket open];
}

- (void)start:(SPBucket *)bucket name:(NSString *)name {
    //[self resetRetryDelay];
    
    SPWebSocketChannel *channel = [self channelForName:bucket.name];
    if (!channel)
        channel = [self loadChannelForBucket:bucket];
    
    if (channel.started)
        return;
    
    if (self.webSocket == nil) {
        [self openWebSocket];
        // Channels will get setup after successfully connection
    } else if (open) {
        [self authenticateChannel:channel];
    }
}

- (void)stop:(SPBucket *)bucket {
    SPWebSocketChannel *channel = [self channelForName:bucket.name];
    channel.started = NO;
    channel.webSocketManager = nil;
    
    // Can't remove the channel because it's needed for offline changes; this is weird and should be fixed
    //[channels removeObjectForKey:bucket.name];

// Note: Proceed closing the socket anyways. There's a possible delay before the open flag gets set to true, while the webSocket is actually open.
// If the websocket is already being closed, the close method call will handle it.
//
//    if (!open) {
//        return;
//    }
	
    DDLogVerbose(@"Simperium stopping network manager (%@)", bucket.name);
    
    // Mark it closed so it doesn't reopen
    open = NO;
    [self.webSocket close];
    self.webSocket = nil;
    
    // TODO: Consider ensuring threads are done their work and sending a notification
}

- (void)resetHeartbeatTimer {
    if (heartbeatTimer != nil)
		[heartbeatTimer invalidate];
	heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:HEARTBEAT target:self selector:@selector(sendHeartbeat:) userInfo:nil repeats:NO];
}

- (void)send:(NSString *)message {
    [self.webSocket send:message];
    [self resetHeartbeatTimer];
}

- (void)sendHeartbeat:(NSTimer *)timer {
    if (self.webSocket.readyState == SR_OPEN) {
        // Send it (will also schedule another one)
        //NSLog(@"Simperium sending heartbeat");
        [self send:@"h:1"];
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
	
	// Reconnection failsafe
	if(webSocket != self.webSocket) {
		return;
	}
	
    open = YES;
    
    // Start all channels
    for (SPWebSocketChannel *channel in [self.channels allValues]) {
        channel.webSocketManager = self;
        [self authenticateChannel:channel];
    }
    
    [self resetHeartbeatTimer];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    self.webSocket = nil;

    if (!open)
        return;
    
    DDLogVerbose(@"Simperium websocket failed (will retry) with error %@", error);
    
    open = NO;
    
    [self performSelector:@selector(openWebSocket) withObject:nil afterDelay:2];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {    
    // Parse CHANNELNUM:COMMAND:DATA
    NSRange range = [message rangeOfString:@":"];
    
    if (range.location == NSNotFound) {
        DDLogError(@"Simperium websocket received invalid message: %@", message);
        return;
    }
    
    NSString *channelStr = [message substringToIndex:range.location];
    
    // Handle heartbeat
    if ([channelStr isEqualToString:@"h"]) {
        //DDLogVerbose(@"Simperium heartbeat acknowledged");
        return;
    }
    
    DDLogVerbose(@"Simperium (%@) received \"%@\"", simperium.label, message);
    
    // It's an actual message; parse/handle it
    NSNumber *channelNumber = [NSNumber numberWithInt:[channelStr intValue]];
    SPWebSocketChannel *channel = [self channelForNumber:channelNumber];
    SPBucket *bucket = [self.simperium bucketForName:channel.name];
    
    NSString *commandStr = [message substringFromIndex:range.location+range.length];    
    range = [commandStr rangeOfString:@":"];
    if (range.location == NSNotFound) {
        DDLogWarn(@"Simperium received unrecognized websocket message: %@", message);
    }
    NSString *command = [commandStr substringToIndex:range.location];
    NSString *data = [commandStr substringFromIndex:range.location+range.length];
    
    if ([command isEqualToString:COM_AUTH]) {
        if ([data isEqualToString:@"expired"]) {
            // Ignore this; legacy
        } else if ([data isEqualToString:simperium.user.email]) {
            channel.started = YES;
            BOOL bFirstStart = bucket.lastChangeSignature == nil;
            if (bFirstStart) {
                [channel requestLatestVersionsForBucket:bucket];
            } else
                [channel startProcessingChangesForBucket:bucket];
        } else {
            DDLogWarn(@"Simperium received unexpected auth response: %@", data);
            NSDictionary *authPayload = [data objectFromJSONStringWithParseOptions:JKParseOptionLooseUnicode];
            NSNumber *code = authPayload[@"code"];
            if ([code isEqualToNumber:@401]) {
                // Let Simperium proper deal with it
                [[NSNotificationCenter defaultCenter] postNotificationName:SPAuthenticationDidFail object:self];
            }
        }
    } else if ([command isEqualToString:COM_INDEX]) {
        [channel handleIndexResponse:data bucket:bucket];
    } else if ([command isEqualToString:COM_CHANGE]) {
        if ([data isEqualToString:@"?"]) {
            // The requested change version didn't exist, so re-index
            DDLogVerbose(@"Simperium change version is out of date (%@), re-indexing", bucket.name);
            [channel requestLatestVersionsForBucket:bucket];
        } else {
            // Incoming changes, handle them
            NSArray *changes = [data objectFromJSONStringWithParseOptions:JKParseOptionLooseUnicode];
			[channel handleRemoteChanges: changes bucket:bucket];
        }
    } else if ([command isEqualToString:COM_ENTITY]) {
        // todo: handle ? if entity doesn't exist or it has been deleted
        [channel handleVersionResponse:data bucket:bucket];
    } else if ([command isEqualToString:COM_ERROR]) {
        DDLogVerbose(@"Simperium returned a command error (?) for bucket %@", bucket.name);
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    if (open) {
        // Closed unexpectedly, retry
        [self performSelector:@selector(openWebSocket) withObject:nil afterDelay:2];
        DDLogVerbose(@"Simperium connection closed (will retry): %ld, %@", (long)code, reason);
    } else {
        // Closed on purpose
        DDLogInfo(@"Simperium connection closed");
    }

    self.webSocket = nil;
    open = NO;
}


-(void)resetBucketAndWait:(SPBucket *)bucket {
    // Careful, this will block if the queue has work on it; however, enqueued tasks should empty quickly if the
    // started flag is set to false
    dispatch_sync(bucket.processorQueue, ^{
        [bucket.changeProcessor reset];
    });
    [bucket setLastChangeSignature:nil];
}

-(void)requestVersions:(int)numVersions object:(id<SPDiffable>)object {
    SPWebSocketChannel *channel = [self channelForName:object.bucket.name];
    [channel requestVersions:numVersions object:object];
}

-(void)shareObject:(id<SPDiffable>)object withEmail:(NSString *)email {
    SPWebSocketChannel *channel = [self channelForName:object.bucket.name];
    [channel shareObject:object withEmail:email];
}

-(void)requestLatestVersionsForBucket:(SPBucket *)b {
    // Not yet implemented
}

-(void)forceSyncBucket:(SPBucket *)bucket {
	// Let's reuse the start mechanism. This will post the latest CV + publish pending changes
	SPWebSocketChannel *channel = [self channelForName:bucket.name];
	[channel startProcessingChangesForBucket:bucket];
}

@end
