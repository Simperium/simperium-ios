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

#warning TODO: Init should have a label
#warning TODO: Can we simplify this?

-(id)init
{
    if((self = [super init]))
    {
        self.queueLock = dispatch_queue_create("com.simperium.http_request_queue", NULL);
		self.enabled = true;
        self.pendingRequests = [NSMutableArray array];
        self.activeRequests = [NSMutableArray array];
    }
    
    return self;
}

#pragma mark ====================================================================================
#pragma mark Public Methods
#pragma mark ====================================================================================

+(instancetype)sharedInstance
{
    static dispatch_once_t _once;
    static id _sharedInstance  = nil;
    
    dispatch_once(&_once, ^{
                      _sharedInstance = [[[self class] alloc] init];
                  });
    
    return _sharedInstance;
}

-(void)enqueueHttpRequest:(SPHttpRequest*)httpRequest
{
    dispatch_sync(self.queueLock, ^(void) {
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
    if( (self.pendingRequests.count == 0) || (self.enabled == false) ) {
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
