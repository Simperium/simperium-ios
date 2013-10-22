//
//  SPHttpRequestQueue.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/21/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPHttpRequestQueue.h"
#import "SPHttpRequest+Internals.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSInteger const SPHttpRequestsMaxConcurrentDownloads = 10;


#pragma mark ====================================================================================
#pragma mark Private Methods
#pragma mark ====================================================================================

@interface SPHttpRequestQueue ()
@property (nonatomic, strong, readwrite) dispatch_queue_t queueLock;
@property (nonatomic, strong, readwrite) NSMutableArray *pendingRequests;
@property (nonatomic, strong, readwrite) NSMutableArray *activeRequests;

-(void)processNextRequest;
@end


#pragma mark ====================================================================================
#pragma mark SPHttpRequestQueue
#pragma mark ====================================================================================

@implementation SPHttpRequestQueue

-(id)init
{
    if((self = [super init]))
    {
        self.queueLock = dispatch_queue_create("com.simperium.SPHttpRequestQueue", NULL);
		self.enabled = true;
		self.maxConcurrentConnections = SPHttpRequestsMaxConcurrentDownloads;
        self.pendingRequests = [NSMutableArray array];
        self.activeRequests = [NSMutableArray array];
    }
    
    return self;
}

#pragma mark ====================================================================================
#pragma mark Public Methods
#pragma mark ====================================================================================

-(void)enqueueHttpRequest:(SPHttpRequest*)httpRequest
{
    dispatch_sync(self.queueLock, ^(void) {
					httpRequest.httpRequestQueue = self;
                    [self.pendingRequests addObject:httpRequest];
                  });
    
    [self processNextRequest];
}

-(void)dequeueHttpRequest:(SPHttpRequest*)httpRequest
{
	[httpRequest stop];
	
    dispatch_sync(self.queueLock, ^(void) {
                      if([self.pendingRequests containsObject:httpRequest]) {
                          [self.pendingRequests removeObject:httpRequest];
					  }
                      
                      if([self.activeRequests containsObject:httpRequest]) {
                          [self.activeRequests removeObject:httpRequest];
                      }
                  });
    
    [self processNextRequest];
}

-(void)processNextRequest
{
    if((self.pendingRequests.count == 0) || (self.activeRequests.count >= _maxConcurrentConnections) || (self.enabled == false)) {
        return;
    }
    
    dispatch_sync(self.queueLock, ^(void) {
                      SPHttpRequest* nextRequest = [self.pendingRequests objectAtIndex:0];
                      
                      [self.activeRequests addObject:nextRequest];
                      [self.pendingRequests removeObjectAtIndex:0];
                      
					  [nextRequest begin];
                  });
}

-(void)setEnabled:(BOOL)enabled
{
	_enabled = enabled;
	if(enabled) {
		[self processNextRequest];
	}
}

-(void)cancelAllRequest
{
	if( (self.activeRequests.count == 0) && (self.pendingRequests.count == 0) ) {
		return;
	}
		
    [self.activeRequests makeObjectsPerformSelector:@selector(cancel)];
    [self.pendingRequests makeObjectsPerformSelector:@selector(cancel)];
	
    dispatch_sync(self.queueLock, ^(void) {
                      [self.activeRequests removeAllObjects];
                      [self.pendingRequests removeAllObjects];
                  });
}

-(void)cancelRequestsWithURL:(NSURL *)url
{
	for (SPHttpRequest *request in self.activeRequests){
		if([request.url isEqual:url]) {
			[request cancel];
		}
	}
}

@end
