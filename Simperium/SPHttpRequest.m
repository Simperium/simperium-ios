//
//  SPHttpRequest.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/21/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPHttpRequest.h"
#import "SPHttpRequestQueue.h"
#import "NSURLResponse+Simperium.h"

#if TARGET_OS_IPHONE
	// Needed for background task support
	#import <UIKit/UIKit.h>
#endif


#pragma mark ====================================================================================
#pragma mark Helpers
#pragma mark ====================================================================================

// Ref: http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown/7073761#7073761

#define SuppressPerformSelectorLeakWarning(Stuff) \
	do { \
		_Pragma("clang diagnostic push") \
		_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
		Stuff; \
		_Pragma("clang diagnostic pop") \
	} while (0)


#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPHttpRequest ()
@property (nonatomic, weak,   readwrite) SPHttpRequestQueue			*httpRequestQueue;
@property (nonatomic, assign, readwrite) SPHttpRequestMethods		method;

#if TARGET_OS_IPHONE
@property (nonatomic, assign, readwrite) BOOL						shouldContinueWhenAppEntersBackground;
@property (nonatomic, assign, readwrite) UIBackgroundTaskIdentifier	backgroundTask;
#endif

@property (nonatomic, strong, readwrite) NSURL						*url;
@property (nonatomic, assign, readwrite) float						uploadProgress;
@property (nonatomic, assign, readwrite) int						responseCode;
@property (nonatomic, strong, readwrite) NSMutableData				*responseMutable;
@property (nonatomic, strong, readwrite) NSError					*responseError;

@property (nonatomic, strong, readwrite) NSURLConnection			*connection;
@property (nonatomic, assign, readwrite) NSStringEncoding			encoding;
@property (nonatomic, assign, readwrite) NSUInteger					retryCount;
@property (nonatomic, strong, readwrite) NSDate						*lastActivityDate;
@end


#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSTimeInterval const SPHttpRequestQueueTimeout	= 30;
static NSUInteger const SPHttpRequestQueueMaxRetries	= 3;


#pragma mark ====================================================================================
#pragma mark SPBinaryDownload
#pragma mark ====================================================================================

@implementation SPHttpRequest

-(id)initWithURL:(NSURL*)url method:(SPHttpRequestMethods)method
{
	if((self = [super init])) {
		self.url = url;
		self.method = method;
		
#if TARGET_OS_IPHONE
		self.shouldContinueWhenAppEntersBackground = YES;
		self.backgroundTask = UIBackgroundTaskInvalid;
#endif
	}
		
	return self;
}

#warning TODO: Persistance


-(NSData *)responseData
{
	return self.responseMutable;
}

-(NSString *)responseString
{
	NSString *responseString = nil;
	
	if (self.responseData) {
		responseString = [[NSString alloc] initWithBytes:self.responseData.bytes length:self.responseData.length encoding:self.encoding];
	}
	
	return responseString;
}



#pragma mark ====================================================================================
#pragma mark Private Methods: iOS Background support
#pragma mark ====================================================================================

-(void)beginBackgroundTask
{
#if TARGET_OS_IPHONE
	if (!self.shouldContinueWhenAppEntersBackground)
	{
		return;
	}
	
	self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.backgroundTask != UIBackgroundTaskInvalid)
			{
				[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
				self.backgroundTask = UIBackgroundTaskInvalid;
				[self cancel];
			}
		});
	}];
#endif
}

-(void)endBackgroundTasks
{
#if TARGET_OS_IPHONE
	if (!self.shouldContinueWhenAppEntersBackground)
	{
		return;
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.backgroundTask != UIBackgroundTaskInvalid) {
			[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
			self.backgroundTask = UIBackgroundTaskInvalid;
		}
	});
#endif
}


#pragma mark ====================================================================================
#pragma mark Protected Methods: Called from SPHttpRequestQueue
#pragma mark ====================================================================================

-(void)begin
{
    ++_retryCount;
    self.responseMutable = [NSMutableData data];
    self.lastActivityDate = [NSDate date];
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
    
	[self beginBackgroundTask];
	
	[self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[self.connection start];
	
	[self performSelector:@selector(checkActivityTimeout) withObject:nil afterDelay:0.1f inModes:@[ NSRunLoopCommonModes ]];
	
	if([self.delegate respondsToSelector:self.selectorStarted]) {
		SuppressPerformSelectorLeakWarning(
			[self.delegate performSelector:self.selectorStarted withObject:self];
		);
	}
}

-(void)stop
{
    // Disable the timeout check
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
	// Warp up BG task
	[self endBackgroundTasks];
	
    // Cleanup
    [self.connection cancel];
    self.connection = nil;
    self.responseMutable = nil;
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
    
    request.HTTPMethod = (self.method == SPHttpRequestMethodsPut) ? @"PUT" : @"GET";
	request.HTTPBody = self.postData;
	
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
		if([self.delegate respondsToSelector:self.selectorFailed]) {
			self.responseError = [NSError errorWithDomain:NSStringFromClass([self class]) code:SPHttpRequestErrorsTimeout userInfo:nil];			
			SuppressPerformSelectorLeakWarning(
				[self.delegate performSelector:self.selectorFailed withObject:self];
			);
		}
		
		[self.httpRequestQueue dequeueHttpRequest:self];
    }
}


#pragma mark ====================================================================================
#pragma mark NSURLConnectionDelegate Methods
#pragma mark ====================================================================================

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseMutable.length = 0;
    self.lastActivityDate = [NSDate date];
	self.encoding = [response encoding];
	
	// Ref: http://stackoverflow.com/questions/6918760/nsurlconnectiondelegate-getting-http-status-codes
	if ([response isKindOfClass:[NSHTTPURLResponse class]])
	{
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
		self.responseCode = (int)[httpResponse statusCode];
	}
	else
	{
		self.responseCode = 501;
	}
	
	if (self.responseCode >= 400)
	{
		NSError *error = [NSError errorWithDomain:NSStringFromClass([self class]) code:self.responseCode userInfo:nil];
		[self connection:connection didFailWithError:error];
	}
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.responseMutable appendData:data];
    self.lastActivityDate = [NSDate date];
	
	if([self.delegate respondsToSelector:self.selectorProgress]) {
		SuppressPerformSelectorLeakWarning(
			[self.delegate performSelector:self.selectorProgress withObject:self];
		);
	}
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if([self.delegate respondsToSelector:self.selectorFailed]) {
		SuppressPerformSelectorLeakWarning(
			[self.delegate performSelector:self.selectorFailed withObject:self];
		);
	}

	[self.httpRequestQueue dequeueHttpRequest:self];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if([self.delegate respondsToSelector:self.selectorSuccess]) {
		SuppressPerformSelectorLeakWarning(
			[self.delegate performSelector:self.selectorSuccess withObject:self];
		);
	}

	[self.httpRequestQueue dequeueHttpRequest:self];
}

-(void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    self.lastActivityDate = [NSDate date];
	self.uploadProgress = totalBytesWritten * 1.0f / totalBytesExpectedToWrite * 1.0f;
}


#pragma mark ====================================================================================
#pragma mark Static Helpers
#pragma mark ====================================================================================

+(SPHttpRequest *)requestWithURL:(NSURL*)url method:(SPHttpRequestMethods)method
{
	return [[self alloc] initWithURL:url method:method];
}

@end
