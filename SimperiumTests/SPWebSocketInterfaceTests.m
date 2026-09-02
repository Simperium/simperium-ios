//
//  SPWebSocketInterfaceTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 11/11/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Simperium.h"
#import "MockSimperium.h"
#import "MockWebSocketInterface.h"
#import "Simperium+Internals.h"
#import "SPLogger.h"
#import "JSONKit+Simperium.h"
#import "Config.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSTimeInterval const SPReconnectionDelay = 2.5;


#pragma mark ====================================================================================
#pragma mark SPWebSocketInterface: Exposing Private Methods
#pragma mark ====================================================================================

@interface SPWebSocketInterface ()
@property (nonatomic, assign, readwrite) BOOL open;
- (instancetype)initWithSimperium:(Simperium *)s;
- (void)openWebSocket;
- (void)webSocket:(SPWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
@end


#pragma mark ====================================================================================
#pragma mark Simperium: Exposing Private Methods
#pragma mark ====================================================================================

@interface Simperium ()
- (void)startNetworkManagers;
@end


#pragma mark ====================================================================================
#pragma mark CountingWebSocketInterface
#pragma mark ====================================================================================

// Counts reconnection attempts without ever touching the network
@interface CountingWebSocketInterface : SPWebSocketInterface
@property (nonatomic, assign, readwrite) NSUInteger openAttempts;
@end

@implementation CountingWebSocketInterface

- (void)openWebSocket {
    self.openAttempts++;
}

@end


#pragma mark ====================================================================================
#pragma mark SPWebSocketInterfaceTests
#pragma mark ====================================================================================

@interface SPWebSocketInterfaceTests : XCTestCase

@end

@implementation SPWebSocketInterfaceTests

- (void)testRemoteLoglevelMessage {
	//	log:<log level>
	//		log level = int, 0 = OFF, 1 = regular, 2 = verbose?
	
	MockSimperium* s = [MockSimperium mockSimperium];
	
	[s.mockWebSocketInterface mockReceiveMessage:@"log:0"];
	XCTAssertFalse(s.verboseLoggingEnabled, @"Error disabling verbose mode");
	XCTAssertFalse(s.remoteLoggingEnabled,	@"Error disabling remote logging");
	
	[s.mockWebSocketInterface mockReceiveMessage:@"log:1"];
	XCTAssertFalse(s.verboseLoggingEnabled, @"Error disabling verbose logging");
	XCTAssertTrue(s.remoteLoggingEnabled,	@"Error enabling remote logging");
	
	[s.mockWebSocketInterface mockReceiveMessage:@"log:2"];
	XCTAssertTrue(s.verboseLoggingEnabled,	@"Error enabling verbose logging");
	XCTAssertTrue(s.remoteLoggingEnabled,	@"Error enabling remote logging");

	// Simulate an error
	SPLogLevels logLevel = SPLogLevelsVerbose;
	NSString* error = @"Simulating Error Message";
	SPLogError(@"%@", error);

	// Release main thread so the log gets posted. (WebSocket gets called only in the main thread)
	[self waitFor:0.1];
	
	// Check if the error got actually posted. We expect:
	//		log:{ "log" : "log message" }
	NSDictionary *payload	= @{ @"log" : error };
	NSString *message		= [NSString stringWithFormat:@"log:%@", [payload sp_JSONString]];
	NSSet *sentMessages		= s.mockWebSocketInterface.mockSentMessages;
	XCTAssertTrue([sentMessages containsObject:message], @"Error message wasn't sent through the WebSocket interface");
}

- (void)testRemoteIndexRequest {
	// Add a new object
	MockSimperium* s		= [MockSimperium mockSimperium];

	SPBucket* bucket		= [s bucketForName:NSStringFromClass([Config class])];
	Config* config			= [bucket insertNewObject];
	config.captainsLog		= @"Alala lala long long le long long long";
	[s save];

	// Let's unlock the main thread. WebSocket interaction is always executed on the main thread.
	[self waitFor:1.0f];
	
	// Index Request
	//		0:index   << 0 is the channel number
	MockWebSocketChannel* channel	= [s.mockWebSocketInterface mockChannelForBucket:bucket];
	NSString* message				= [NSString stringWithFormat:@"%d:index", channel.number];
	[s.mockWebSocketInterface mockReceiveMessage:message];
	
	//	Index Response
	//		0:index:{ current: <cv>, index: { {id: <eid>, v: <version>}, ... }, pending: { { id: <eid>, sv: <version>, ccid: <ccid> }, ... }, extra: { ? } }
	BOOL responseSent = NO;
	for (id sent in s.mockWebSocketInterface.mockSentMessages) {
		NSRange range			= [sent rangeOfString:@":"];
		NSString *msgChannel	= [sent substringToIndex:range.location];
		NSString *msgCommand	= [sent substringFromIndex:range.location+range.length];
		
		if ([msgChannel intValue] != channel.number || [msgCommand hasPrefix:@"index:"] == NO) {
			continue;
		}
		
		responseSent = YES;
		range = [msgCommand rangeOfString:@":"];
		NSDictionary* payload = [[msgCommand substringFromIndex:range.location+range.length] sp_objectFromJSONString];
		
		NSArray* index = payload[@"index"];
		NSString* current = payload[@"current"];
		NSArray* pendings = payload[@"pendings"];
		
		XCTAssertNotNil(index,			@"Missing current field");
		XCTAssertNotNil(current,		@"Missing current field");
		XCTAssertNotNil(pendings,		@"Missing current field");
		XCTAssertTrue(index.count == 1,	@"Index Inconsistency");
		
		break;
	}
	
	XCTAssertTrue(responseSent, @"Index Request-Response wasn't sent!!");
}

- (void)testSocketClosedBeforeFinishingHandshakeSchedulesReconnection {
	// A close that arrives before webSocketDidOpen (open == NO) used to be treated as an
	// intentional close, wedging the interface: no socket, no retry, and nothing upstream
	// notices. See SIMPL-75.
	MockSimperium* s = [MockSimperium mockSimperium];
	CountingWebSocketInterface* interface = [[CountingWebSocketInterface alloc] initWithSimperium:s];

	interface.open = NO;
	[interface webSocket:nil didCloseWithCode:1006 reason:@"connection dropped mid-handshake" wasClean:NO];

	[self waitFor:SPReconnectionDelay];
	XCTAssertTrue(interface.openAttempts > 0, @"A close during connection setup must schedule a reconnection");
}

- (void)testSocketClosedAfterOpeningSchedulesReconnection {
	MockSimperium* s = [MockSimperium mockSimperium];
	CountingWebSocketInterface* interface = [[CountingWebSocketInterface alloc] initWithSimperium:s];

	interface.open = YES;
	[interface webSocket:nil didCloseWithCode:1006 reason:@"connection dropped" wasClean:NO];

	[self waitFor:SPReconnectionDelay];
	XCTAssertTrue(interface.openAttempts > 0, @"An unexpected close must schedule a reconnection");
}

- (void)testSocketClosedWhileNetworkDisabledDoesNotReconnect {
	MockSimperium* s = [MockSimperium mockSimperium];
	CountingWebSocketInterface* interface = [[CountingWebSocketInterface alloc] initWithSimperium:s];
	s.networkEnabled = NO;

	interface.open = NO;
	[interface webSocket:nil didCloseWithCode:1006 reason:@"connection dropped" wasClean:NO];

	[self waitFor:SPReconnectionDelay];
	XCTAssertTrue(interface.openAttempts == 0, @"No reconnection should be attempted while networking is disabled");
}

- (void)testStopCancelsPendingReconnection {
	MockSimperium* s = [MockSimperium mockSimperium];
	SPBucket* bucket = [s bucketForName:NSStringFromClass([Config class])];
	CountingWebSocketInterface* interface = [[CountingWebSocketInterface alloc] initWithSimperium:s];

	interface.open = YES;
	[interface webSocket:nil didCloseWithCode:1006 reason:@"connection dropped" wasClean:NO];
	[interface stop:bucket];

	[self waitFor:SPReconnectionDelay];
	XCTAssertTrue(interface.openAttempts == 0, @"An intentional stop must cancel any pending reconnection");
}

- (void)testStartNetworkManagersRestartsBucketsEvenWhenAlreadyFlaggedAsStarted {
	// The networkManagersStarted flag only records that start was called once; the websocket
	// may have been dropped since. Restarting must reach the network interface regardless,
	// since SPWebSocketInterface's start: is idempotent for healthy connections.
	MockSimperium* s = [MockSimperium mockSimperium];
	[s bucketForName:NSStringFromClass([Config class])];
	XCTAssertTrue(s.networkManagersStarted, @"Expected network managers to be started after authentication");

	[s.mockWebSocketInterface mockClearStartedBucketNames];
	[s startNetworkManagers];

	XCTAssertTrue(s.mockWebSocketInterface.mockStartedBucketNames.count > 0,
				  @"Restarting network managers must restart the buckets' network interface");
}

@end
