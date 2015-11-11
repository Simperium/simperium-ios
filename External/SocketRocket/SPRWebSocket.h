//
//   Copyright 2012 Square Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>

typedef NS_ENUM(NSInteger, SPRReadyState) {
    SPR_CONNECTING   = 0,
    SPR_OPEN         = 1,
    SPR_CLOSING      = 2,
    SPR_CLOSED       = 3,
};

typedef NS_ENUM(NSInteger, SPRStatusCode) {
    SPRStatusCodeNormal = 1000,
    SPRStatusCodeGoingAway = 1001,
    SPRStatusCodeProtocolError = 1002,
    SPRStatusCodeUnhandledType = 1003,
    // 1004 reserved.
    SPRStatusNoStatusReceived = 1005,
    // 1004-1006 reserved.
    SPRStatusCodeInvalidUTF8 = 1007,
    SPRStatusCodePolicyViolated = 1008,
    SPRStatusCodeMessageTooBig = 1009,
};

@class SPRWebSocket;

extern NSString *const SPRWebSocketErrorDomain;
extern NSString *const SPRHTTPResponseErrorKey;

#pragma mark - SPRWebSocketDelegate

@protocol SPRWebSocketDelegate;

#pragma mark - SPRWebSocket

@interface SPRWebSocket : NSObject <NSStreamDelegate>

@property (nonatomic, weak) id <SPRWebSocketDelegate> delegate;

@property (nonatomic, readonly) SPRReadyState readyState;
@property (nonatomic, readonly, retain) NSURL *url;

// This returns the negotiated protocol.
// It will be nil until after the handshake completes.
@property (nonatomic, readonly, copy) NSString *protocol;

// Protocols should be an array of strings that turn into Sec-WebSocket-Protocol.
- (id)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray *)protocols;
- (id)initWithURLRequest:(NSURLRequest *)request;

// Some helper constructors.
- (id)initWithURL:(NSURL *)url protocols:(NSArray *)protocols;
- (id)initWithURL:(NSURL *)url;

// Delegate queue will be dispatch_main_queue by default.
// You cannot set both OperationQueue and dispatch_queue.
- (void)setDelegateOperationQueue:(NSOperationQueue*) queue;
- (void)setDelegateDispatchQueue:(dispatch_queue_t) queue;

// By default, it will schedule itself on +[NSRunLoop SPR_networkRunLoop] using defaultModes.
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;

// SPRWebSockets are intended for one-time-use only.  Open should be called once and only once.
- (void)open;

- (void)close;
- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason;

// Send a UTF8 String or Data.
- (void)send:(id)data;

// Send Data (can be nil) in a ping message.
- (void)sendPing:(NSData *)data;

@end

#pragma mark - SPRWebSocketDelegate

@protocol SPRWebSocketDelegate <NSObject>

// message will either be an NSString if the server is using text
// or NSData if the server is using binary.
- (void)webSocket:(SPRWebSocket *)webSocket didReceiveMessage:(id)message;

@optional

- (void)webSocketDidOpen:(SPRWebSocket *)webSocket;
- (void)webSocket:(SPRWebSocket *)webSocket didFailWithError:(NSError *)error;
- (void)webSocket:(SPRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
- (void)webSocket:(SPRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload;

@end

#pragma mark - NSURLRequest (CertificateAdditions)

@interface NSURLRequest (SPRCertificateAdditions)

@property (nonatomic, retain, readonly) NSArray *SPR_SSLPinnedCertificates;

@end

#pragma mark - NSMutableURLRequest (CertificateAdditions)

@interface NSMutableURLRequest (CertificateAdditions)

@property (nonatomic, retain) NSArray *SPR_SSLPinnedCertificates;

@end

#pragma mark - NSRunLoop (SPRWebSocket)

@interface NSRunLoop (SPRWebSocket)

+ (NSRunLoop *)SPR_networkRunLoop;

@end
