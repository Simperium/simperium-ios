//
//  SPHttpRequest.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/21/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPHttpRequest.h"
#import "SPHttpRequestQueue.h"



#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPHttpRequest ()
@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, strong, readwrite) NSDictionary *headers;
@property (nonatomic, strong, readwrite) NSDictionary *userInfo;
@property (nonatomic, assign, readwrite) SPHttpRequestMethods method;

@property (nonatomic, strong, readwrite) NSURLConnection *connection;
@property (nonatomic, strong, readwrite) NSMutableData *receivedData;
@property (nonatomic, assign, readwrite) NSUInteger retryCount;
@property (nonatomic, strong, readwrite) NSDate *lastActivityDate;
@end


#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSTimeInterval const SPHttpRequestQueueTimeout	= 30;
static NSUInteger const SPHttpRequestQueueMaxRetries	= 2;


#pragma mark ====================================================================================
#pragma mark SPBinaryDownload
#pragma mark ====================================================================================

@implementation SPHttpRequest

-(id)initWithURL:(NSURL*)url
		 headers:(NSDictionary*)headers
		userInfo:(NSDictionary *)userInfo
		  method:(SPHttpRequestMethods)method
		delegate:(id<SPHttpRequestDelegate>)delegate
{
	if((self = [super init])) {
		self.url = url;
		self.headers = headers;
		self.userInfo = userInfo;
		self.method = method;
		self.delegate = delegate;
	}
		
	return self;
}

#warning TODO: Persistance

-(void)enqueue
{
    [[SPHttpRequestQueue sharedInstance] enqueueHttpRequest:self];
}

-(void)dequeue
{
    [self stop];
    [[SPHttpRequestQueue sharedInstance] dequeueHttpRequest:self];
}


#pragma mark ====================================================================================
#pragma mark Protected Methods: Called from SPHttpRequestQueue
#pragma mark ====================================================================================

-(void)begin
{
    ++_retryCount;
    self.receivedData = [NSMutableData data];
    self.lastActivityDate = [NSDate date];
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
    
	[self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[self.connection start];
	
	[self performSelector:@selector(checkActivityTimeout) withObject:nil afterDelay:0.1f inModes:@[ NSRunLoopCommonModes ]];
}

-(void)stop
{
    // Disable the timeout check
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    // Cleanup
    [self.connection cancel];
    self.connection = nil;
    self.receivedData = nil;
}

-(void)cancel
{
	self.delegate = nil;
	[self stop];
}


#pragma mark ====================================================================================
#pragma mark Private Helper Methods
#pragma mark ====================================================================================

-(NSURLRequest*)request
{
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:self.url	cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:SPHttpRequestQueueTimeout];
    
    for(NSString* headerField in [self.headers allKeys]) {
        [request setValue:self.headers[headerField] forHTTPHeaderField:headerField];
    }
    
    request.HTTPMethod = (self.method == SPHttpRequestMethodsPost) ? @"POST" : @"GET";
    
    return request;
}

-(void)checkActivityTimeout
{
    NSTimeInterval secondsSinceLastActivity = [[NSDate date] timeIntervalSinceDate:self.lastActivityDate];
    
    if ((secondsSinceLastActivity < SPHttpRequestQueueTimeout))
    {
		[self performSelector:@selector(checkActivityTimeout) withObject:nil afterDelay:0.1f inModes:@[ NSRunLoopCommonModes ]];
        return;
    }
	
    [self stop];
    
    if(self.retryCount < SPHttpRequestQueueMaxRetries) {
        [self begin];
    } else {
		if([self.delegate respondsToSelector:@selector(httpRequestFailed:error:)]) {
			NSError *error = [NSError errorWithDomain:NSStringFromClass([self class]) code:SPHttpRequestErrorsTimeout userInfo:nil];
			[self.delegate httpRequestFailed:self error:error];
		}
		
        [self dequeue];
    }
}


#pragma mark ====================================================================================
#pragma mark NSURLConnectionDelegate Methods
#pragma mark ====================================================================================

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.receivedData.length = 0;
    self.lastActivityDate = [NSDate date];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.receivedData appendData:data];
    self.lastActivityDate = [NSDate date];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if([self.delegate respondsToSelector:@selector(httpRequestFailed:error:)]) {
		[self.delegate httpRequestFailed:self error:error];
	}
    [self dequeue];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if([self.delegate respondsToSelector:@selector(httpRequestSuccessful:data:)]) {
		[self.delegate httpRequestSuccessful:self data:self.receivedData];
	}
    [self dequeue];
}

-(void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    self.lastActivityDate = [NSDate date];
}


#pragma mark ====================================================================================
#pragma mark Static Helpers
#pragma mark ====================================================================================

+(SPHttpRequest *)requestWithURL:(NSURL *)url
						 headers:(NSDictionary *)headers
						userInfo:(NSDictionary *)userInfo
						  method:(SPHttpRequestMethods)method
						delegate:(id<SPHttpRequestDelegate>)delegate
{
	return [[self alloc] initWithURL:url headers:headers userInfo:userInfo method:method delegate:delegate];
}

@end
