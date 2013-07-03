//
//  SPHttpManager.m
//  Simperium
//
//  Created by Michael Johnston on 11-03-07.
//  Copyright 2011 Simperium. All rights reserved.
//

#define DEBUG_REQUEST_STATUS
#import "SPEnvironment.h"
#import "SPHttpInterface.h"
#import "Simperium.h"
#import "SPDiffer.h"
#import "SPBucket.h"
#import "SPStorage.h"
#import "SPUser.h"
#import "SPChangeProcessor.h"
#import "SPIndexProcessor.h"
#import "SPMember.h"
#import "SPGhost.h"
#import <ASIHTTPRequest/ASIHTTPRequest.h>
#import "ASINetworkQueue.h"
#import <JSONKit/JSONKit.h>
#import "NSString+Simperium.h"
#import "DDLog.h"
#import "DDLogDebug.h"
#import <objc/runtime.h>

#define INDEX_PAGE_SIZE 500
#define INDEX_BATCH_SIZE 10
#define INDEX_QUEUE_SIZE 5

static NSUInteger numTransfers = 0;
static BOOL useNetworkActivityIndicator = 0;
static BOOL networkActivity = NO;

static int ddLogLevel = LOG_LEVEL_INFO;
NSString * const AuthenticationDidFailNotification = @"AuthenticationDidFailNotification";

@interface SPHttpInterface()
@property (nonatomic, weak) Simperium *simperium;
@property (nonatomic, weak) SPBucket *bucket;
@property (nonatomic, strong) NSMutableArray *responseBatch;
@property (nonatomic, strong) NSMutableDictionary *versionsWithErrors;
@property (nonatomic, copy) NSString *clientID;
@property (nonatomic, copy) NSString *remoteBucketName;

-(void)indexQueueFinished:(ASINetworkQueue *)queue;
-(void)allVersionsFinished:(ASINetworkQueue *)queue;
-(void)getIndexFailed:(ASIHTTPRequest *)request;
-(void)getVersionFailed:(ASIHTTPRequest *)request;
@end

@implementation SPHttpInterface
@synthesize simperium;
@synthesize bucket;
@synthesize responseBatch;
@synthesize versionsWithErrors;
@synthesize nextMark;
@synthesize indexArray;
@synthesize remoteBucketName;
@synthesize clientID;
@synthesize pendingLastChangeSignature;

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

+ (void)updateNetworkActivityIndictator
{
    if (networkActivity && numTransfers == 0) {
        // Activity stopped
        networkActivity = NO;
        //if ([self.simperium.delegate respondsToSelector:@selector(simperiumDidFinishNetworkActivity:)])
        //    [self.simperium.delegate simperiumDidFinishNetworkActivity:self.simperium];
    } else {
        
    }
#if TARGET_OS_IPHONE    
    BOOL visible = useNetworkActivityIndicator && numTransfers > 0;
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:visible];
    //DDLogInfo(@"Simperium numTransfers = %d", numTransfers);
#endif
}

+ (void)setNetworkActivityIndicatorEnabled:(BOOL)enabled
{
    useNetworkActivityIndicator = enabled;
}

-(id)initWithSimperium:(Simperium *)s appURL:(NSString *)url clientID:(NSString *)cid
{
	if ((self = [super init])) {
        self.simperium = s;
        self.indexArray = [NSMutableArray arrayWithCapacity:200];
        self.clientID = cid;
				
        [[ASIHTTPRequest sharedQueue] setMaxConcurrentOperationCount:30];
        
        self.versionsWithErrors = [NSMutableDictionary dictionaryWithCapacity:3];        
	}
	
	return self;
}

-(void)dealloc
{
	[getRequest clearDelegatesAndCancel];
	[postRequest clearDelegatesAndCancel];
}

-(void)setBucket:(SPBucket *)aBucket overrides:(NSDictionary *)overrides {
    self.bucket = aBucket;
    self.remoteBucketName = [overrides objectForKey:self.bucket.name];
    if (!self.remoteBucketName) {
        self.remoteBucketName = self.bucket.name;
    }
}

-(void)authenticationDidFail {
    DDLogWarn(@"Simperium authentication failed for token %@", simperium.user.authToken);
    [[NSNotificationCenter defaultCenter] postNotificationName:AuthenticationDidFailNotification object:self];
}

-(void)sendChange:(NSDictionary *)change forKey:(NSString *)key
{
    DDLogVerbose(@"Simperium adding pending change and cancelling getRequest (%@): %@", bucket.name, key);
    // Since pendingChanges is a dictionary, only the latest local unsent change per entity is ever used

    [bucket.changeProcessor processLocalChange:change key:key];
    dispatch_async(dispatch_get_main_queue(), ^{
        // Cancel the long polling connection so that no updates are received while we're waiting for the server to
        // acknowledge the forthcoming change. This will cause the response error handler to be called, which will
        // in turn cause any changesPending to be sent.
         
        // However, only do this if the manager is started. Otherwise, the change will still be in changesPending
        // and it'll be sent the next time the manager is started.
         
        // Also only do this if the entity isn't already awaiting an ack for a previously sent change. Only one
        // change per entity can be on the wire at a time.
         
        if (started && [getRequest isExecuting]) {
            requestCancelled = YES;
            [getRequest cancel];   
            // This cancellation will lead to changes being posted
        }
    });
}

-(void)sendObjectDeletion:(id<SPDiffable>)object
{
    NSString *key = [object simperiumKey];
    DDLogVerbose(@"Simperium sending entity DELETION change: %@/%@", bucket.name, key); 
    
    // Send the deletion change (which will also overwrite any previous unsent local changes)
    // This could cause an ACK to fail if the deletion is registered before a previous change was ACK'd, but that should be OK since the object will be deleted anyway.
    
    if (key == nil) {
        DDLogWarn(@"Simperium received DELETION request for nil key");
        return;
    }
    
    dispatch_async(bucket.processorQueue, ^{
        NSDictionary *change = [bucket.changeProcessor processLocalDeletionWithKey: key];
        
        // If client is offline and another change is pending, this will overwrite it, which is OK since the object won't exist anymore
        [self sendChange: change forKey: key];
    });
}

-(void)sendObjectChanges:(id<SPDiffable>)object
{
    // Consider being more careful about faulting here (since only the simperiumKey is needed)
    NSString *key = [object simperiumKey];
    if (key == nil) {
        DDLogWarn(@"Simperium tried to send changes for an object with a nil simperiumKey (%@)", bucket.name);
        return;
    }
    
    dispatch_async(bucket.processorQueue, ^{
        NSDictionary *change = [bucket.changeProcessor processLocalObjectWithKey:key bucket:bucket later:gettingVersions || !started];
        if (change)
            [self sendChange: change forKey: key]; 
    });
}

-(void)getChanges
{
    if (gettingVersions || !started)
        return;
    
    if ([getRequest isExecuting]) {
        DDLogWarn(@"Simperium get request already in progress");
        return;
    }
    
    if (![simperium.user authToken]) {
        DDLogWarn(@"Simperium get request without valid user token");
        return;
    }
    
	NSMutableString *getURL = [simperium.appURL mutableCopy];
    [getURL appendFormat:@"%@/changes", remoteBucketName];
	if (bucket.lastChangeSignature.length > 0)
		[getURL appendFormat:@"?cv=%@", bucket.lastChangeSignature];
	
    DDLogVerbose(@"Simperium getting changes: %@", getURL);
	
	// PERFORM GET Content/json on retrieveURL, but it's a long poll
	// Need callbacks for when changes come in, and when there's an error (or cancelled)
	NSURL *url = [NSURL URLWithString:getURL];
    
	getRequest = [ASIHTTPRequest requestWithURL:url];
	[getRequest addRequestHeader:@"Content-Type" value:@"application/json"];
	[getRequest addRequestHeader:@"X-Simperium-Token" value:[simperium.user authToken]];
	[getRequest setDelegate:self]; 
	[getRequest setPersistentConnectionTimeoutSeconds:120];
	[getRequest setTimeOutSeconds:120];
    [getRequest setDidFinishSelector:@selector(getChangesFinished:)];
    [getRequest setDidFailSelector:@selector(getChangesFailed:)];
	[getRequest startAsynchronous];
}

-(void)postChanges
{    
    if (!started)
        return;
    
    dispatch_async(bucket.processorQueue, ^{
        NSArray *changes = [bucket.changeProcessor processPendingChanges:bucket onlyQueuedChanges:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([changes count] == 0) {
                [self getChanges];
                return;
            }
            
            NSMutableString *sendURL = [simperium.appURL mutableCopy];
            [sendURL appendFormat:@"%@/changes?clientid=%@&wait=1",remoteBucketName, self.clientID];
            DDLogVerbose(@"Simperium posting changes: %@", sendURL);
            
            // Update activity indicator
            numTransfers++;
            [[self class] updateNetworkActivityIndictator];

            // PERFORM GET
            NSURL *url = [NSURL URLWithString:sendURL];
            
            NSString *jsonStr = [changes JSONString];
            DDLogVerbose(@"  post data = %@", jsonStr);
            
            postRequest = [ASIHTTPRequest requestWithURL:url];
            [postRequest appendPostData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding]];
            //[sendRequest addRequestHeader:@"Content-Type" value:@"application/json"];
            [postRequest addRequestHeader:@"X-Simperium-Token" value:[simperium.user authToken]];
            [postRequest setDelegate:self];
            [postRequest setDidFinishSelector:@selector(postChangesFinished:)];
            [postRequest setDidFailSelector:@selector(postChangesFailed:)];
#if TARGET_OS_IPHONE
            postRequest.shouldContinueWhenAppEntersBackground = YES;
#endif
            [postRequest startAsynchronous];  
        });
    });
}

-(void)startProcessingChanges
{
    __block int numChangesPending;
    __block int numKeysForObjectsWithMoreChanges;
    dispatch_async(bucket.processorQueue, ^{
        if (started) {
            numChangesPending = [bucket.changeProcessor numChangesPending];
            numKeysForObjectsWithMoreChanges = [bucket.changeProcessor numKeysForObjectsWithMoreChanges];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // One more check in case Simperium was started, stopped, and started in rapid succession
                if (!started)
                    return;
                
                if (numChangesPending > 0 || numKeysForObjectsWithMoreChanges > 0) {
                    // Send the offline changes
                    DDLogVerbose(@"Simperium sending %u pending offline changes (%@) plus %d objects with more", numChangesPending, bucket.name, numKeysForObjectsWithMoreChanges);
                    [self postChanges];
                } else {
                    // Nothing to send, so start getting changes right away
                    [self getChanges];  
                }
            });
        }
    }); 
}

- (int)nextRetryDelay {
    int currentDelay = retryDelay;
    retryDelay *= 2;
    if (retryDelay > 24)
        retryDelay = 24;
    
    return currentDelay;
}

- (void)resetRetryDelay {
    retryDelay = 2;
}

-(void)start:(SPBucket *)startBucket name:(NSString *)name
{    
    if (started)
        return;
    
    started = YES;
    [self resetRetryDelay];

    // TODO: Is this the best and only way to detect when an index of latest versions is needed?
    BOOL bFirstStart = bucket.lastChangeSignature == nil;
    if (bFirstStart) {
        [self requestLatestVersionsForBucket:startBucket];
    } else
        [self startProcessingChanges];
}

-(void)stop:(SPBucket *)bucket
{
    if (!started)
        return;
    
    DDLogVerbose(@"Simperium stopping network manager (%@)", self.bucket.name);
    started = NO;
    // TODO: Make sure it's safe to arbitrarily cancel these requests
    [getRequest clearDelegatesAndCancel];
    getRequest = nil;
	[postRequest clearDelegatesAndCancel];
    postRequest = nil;
    
    // TODO: Consider ensuring threads are done their work and sending a notification
}

-(void)resetBucketAndWait:(SPBucket *)b
{
    // Careful, this will block if the queue has work on it; however, enqueued tasks should empty quickly if the
    // started flag is set to false
    dispatch_sync(b.processorQueue, ^{
        [b.changeProcessor reset];
    });
    [b setLastChangeSignature:nil];

    numTransfers = 0;
    [[self class] updateNetworkActivityIndictator];
}

-(void)handleRemoteChanges:(NSArray *)changes
{    
    // Changing entities and saving the context will clear Core Data's updatedObjects. Stash them so
    // sync will still work for any unsaved changes.
    [bucket.storage stashUnsavedObjects];
            
    numTransfers++;
    [[self class] updateNetworkActivityIndictator];

    dispatch_async(bucket.processorQueue, ^{
        if (started) {
            [bucket.changeProcessor processRemoteChanges:changes bucket:bucket clientID:clientID];
            dispatch_async(dispatch_get_main_queue(), ^{
                numTransfers--;
                [[self class] updateNetworkActivityIndictator];

                [self postChanges];
            });
        }
    });
}

#pragma mark Request handling for changes

- (void)getChangesFinished:(ASIHTTPRequest *)request
{
	NSString *responseString = [request responseString];
	int responseCode = [request responseStatusCode];
    
    if (responseCode == 404) {
        // Perform a re-indexing here
        DDLogVerbose(@"Simperium version not found, initiating re-indexing (%@)", [request originalURL]);
        [self requestLatestVersionsForBucket:self.bucket];
        return;
    }

    if (responseCode != 200 || responseString.length == 0) {
        [self resetRetryDelay];
        DDLogVerbose(@"Simperium timeout, server didn't respond to GET code %d (%@), retrying in 5 seconds...", responseCode, bucket.name);
        if (responseCode != 504 && responseCode != 500 && responseString.length > 0)
            DDLogVerbose(@"  server response was: %@", responseString);
        [self performSelector:@selector(postChanges) withObject:nil afterDelay:5];
        return;
    }
    NSArray *changes = [responseString objectFromJSONStringWithParseOptions:JKParseOptionLooseUnicode];
    DDLogVerbose(@"GET response received (%@), handling %lu changes...", bucket.name, (unsigned long)[changes count] );
    DDLogDebug(@"  GET response was: %@", responseString);
    
    [self resetRetryDelay];

    [self handleRemoteChanges: changes];
}

- (void)postChangesFinished:(ASIHTTPRequest *)request
{
    NSString *responseString = [request responseString];
	int responseCode = [request responseStatusCode];
    numTransfers--;
    [[self class] updateNetworkActivityIndictator];

    if (responseCode == 502 || responseCode == 503) {
        if (started) {
            DDLogWarn(@"Simperium warning (will retry), server didn't respond to POST (%@)", bucket.name);
            [self performSelector:@selector(postChanges) withObject:nil afterDelay:[self nextRetryDelay]];
        }
        return;
    }
    
    [self resetRetryDelay];

    // Check for any errors in the response
    if (responseString.length > 0) {
        NSArray *changes = [responseString objectFromJSONString];
        dispatch_async(bucket.processorQueue, ^{
            if (started) {
                BOOL repostNeeded = [bucket.changeProcessor processRemoteResponseForChanges:changes bucket:bucket];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!repostNeeded) {
                        // Pending changes were successfully sent, so start long polling for changes again
                        // in order to get an ack
                        DDLogVerbose(@"POST response received (%@), back to handling changes... %@",bucket.name, responseString);
                        [self getChanges];
                    } else {
                        // There was an error that requires reposting
                        DDLogVerbose(@"POST response received (%@) but REPOST is required %@", bucket.name, responseString);
                        [self performSelector:@selector(postChanges) withObject:nil afterDelay:2];                            
                    }
                });
            }
        });
    }
}

- (void)getChangesFailed:(ASIHTTPRequest *)request
{
    // Check if the manager is being stopped (which cancels the request, causing it to fail)
    if (!started)
        return;
    
	NSError *error = [request error];
	DDLogVerbose(@"Received GET request code %d (%@): %@", [request responseStatusCode], bucket.name, [error localizedDescription]);	
	
    int retry = 5;
    // The long polling for retrieving change was probably cancelled in order to send changes
    if (requestCancelled) {
        [self postChanges];
        requestCancelled = NO;
        return;
    } else if ([request responseStatusCode] == 401) {
        // User credentials changed
        [self authenticationDidFail];
    } else
        // Some other problem, so backoff
        retry = [self nextRetryDelay];
    // There's a problem, e.g. the server isn't up, so keep trying to reconnect
    DDLogVerbose(@"Retrying in %d seconds...", retry);
    [self performSelector:@selector(postChanges) withObject:nil afterDelay:retry];
}

- (void)postChangesFailed:(ASIHTTPRequest *)request
{   
    numTransfers--;
    [[self class] updateNetworkActivityIndictator];

    // Check if the manager is being stopped (which cancels the request, causing it to fail)
    if (!started)
        return;
    
    if ([request responseStatusCode] == 401) {
        // User credentials changed
        [self authenticationDidFail];
    }
    
	NSError *error = [request error];
	DDLogVerbose(@"Received POST request error (will retry), code %d (%@): %@", [request responseStatusCode], bucket.name, [error localizedDescription]);	

    // If posting changes failed, then they need to be retried again before any more changes are retrieved
    [self performSelector:@selector(postChanges) withObject:nil afterDelay:[self nextRetryDelay]];
}

#pragma mark Index handling

-(void)requestLatestVersionsMark:(NSString *)mark
{
    if (!simperium.user) {
        DDLogError(@"Simperium critical error: tried to retrieve index with no user set");
        return;
    }
    
    // Don't get changes while processing an index
    if ([getRequest isExecuting]) {
        DDLogVerbose(@"Simperium cancelling get request to retrieve index");
        [getRequest clearDelegatesAndCancel];
    }
    
    // Get an index of all objects and fetch their latest versions
    gettingVersions = YES;
    
    // TODO: remove /index after it's been deployed and tested
    NSString *indexURL = [simperium.appURL stringByAppendingFormat:@"%@/index?limit=%d", remoteBucketName, INDEX_PAGE_SIZE];
    if (mark)
        indexURL = [indexURL stringByAppendingFormat:@"&mark=%@", mark];
    NSURL *url = [NSURL URLWithString:indexURL];
    DDLogVerbose(@"Simperium requesting index (%@): %@", bucket.name, [url absoluteString]);
    ASIHTTPRequest *indexRequest = [ASIHTTPRequest requestWithURL:url];
    numTransfers++;
    [[self class] updateNetworkActivityIndictator];
    
    NSString *token = [simperium.user authToken];
    
    if (!token) {
        DDLogError(@"Simperium missing an auth token; unable to retrieve index (%@)", bucket.name);
        return;
    }
    [indexRequest addRequestHeader:@"X-Simperium-Token" value:token];
    [indexRequest setDelegate:self];
    [indexRequest setDidFinishSelector:@selector(getIndexFinished:)];
    [indexRequest setDidFailSelector:@selector(getIndexFailed:)];
#if TARGET_OS_IPHONE
    indexRequest.shouldContinueWhenAppEntersBackground = YES;
#endif
    [indexRequest startAsynchronous];
}

-(void)requestLatestVersionsForBucket:(SPBucket *)b {
    // Multiple errors could try to trigger multiple index refreshes
    if (gettingVersions)
        return;
    
    // Might be retried after network has stopped
    if (!started) {
        DDLogVerbose(@"Simperium cancelling index retry because networking has stopped");
        return;
    }
    
    [self requestLatestVersionsMark:nil];
}

-(ASIHTTPRequest *)getRequestForKey:(NSString *)key version:(NSString *)version
{
    if (![simperium.user authToken]) {
        DDLogWarn(@"Simperium getRequestForKey without valid user token");
        return nil;
    }

    // Otherwise, need to get the latest version
    NSURL *url = [NSURL URLWithString:[simperium.appURL stringByAppendingFormat:@"%@/i/%@/v/%@",
                                       remoteBucketName,
                                       key,//[key urlEncodeString],
                                       version]];
    ASIHTTPRequest *versionRequest = [ASIHTTPRequest requestWithURL: url];
    [versionRequest addRequestHeader:@"X-Simperium-Token" value:[simperium.user authToken]];
    return versionRequest;
}

-(void)getVersionsForKeys:(NSArray *)currentIndexArray {
    // Changing entities and saving the context will clear Core Data's updatedObjects. Stash them so
    // sync will still work later for any unsaved changes.
    // In the time between now and when the index refresh completes, any local changes will get marked
    // since regular syncing is disabled during index retrieval.
    [bucket.storage stashUnsavedObjects];
    
    if ([bucket.delegate respondsToSelector:@selector(bucketWillStartIndexing:)])
        [bucket.delegate bucketWillStartIndexing:bucket];
    
    self.responseBatch = [NSMutableArray arrayWithCapacity:INDEX_BATCH_SIZE];
    
    // Get all the latest versions
    ASINetworkQueue *networkQueue = [ASINetworkQueue queue];
    [networkQueue setDelegate:self];
    [networkQueue setQueueDidFinishSelector:@selector(indexQueueFinished:)];
    [networkQueue setRequestDidFinishSelector:@selector(getVersionFinished:)];
    [networkQueue setRequestDidFailSelector:@selector(getVersionFailed:)];
    [networkQueue setMaxConcurrentOperationCount:INDEX_QUEUE_SIZE];
    
    DDLogInfo(@"Simperium processing %lu objects from index (%@)", (unsigned long)[currentIndexArray count], bucket.name);
    
    NSArray *indexArrayCopy = [currentIndexArray copy];
    __block int numVersionRequests = 0;
    dispatch_async(bucket.processorQueue, ^{
        if (started) {
            [bucket.indexProcessor processIndex:indexArrayCopy bucket:bucket versionHandler: ^(NSString *key, NSString *version) {
                numVersionRequests++;
                
                // For each version that is processed, create a network request
                ASIHTTPRequest *versionRequest = [self getRequestForKey:key version:version];
                if (versionRequest) {
        #if TARGET_OS_IPHONE
                    versionRequest.shouldContinueWhenAppEntersBackground = YES;
        #endif
                    DDLogVerbose(@"Simperium enqueuing object request (%@): %@", bucket.name, [[versionRequest url] absoluteString]);
                    [networkQueue addOperation:versionRequest];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        numTransfers += 1;
                        [[self class] updateNetworkActivityIndictator];
                    });
                }
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // If no requests need to be queued, then all is good; back to processing
                if (numVersionRequests == 0) {
                    [self indexQueueFinished:nil];
                    return;
                }
                
                DDLogInfo(@"Simperium enqueuing %d object requests (%@)", numVersionRequests, bucket.name);
                [networkQueue go];
            });
        }
    });

}

-(void)getIndexFinished:(ASIHTTPRequest *)request
{
    if (request.responseStatusCode != 200) {
        [self getIndexFailed:request];
        return;
    }
    
    NSString *responseString = [request responseString];
    DDLogVerbose(@"Simperium received index (%@): %@", bucket.name, responseString);
    NSDictionary *responseDict = [responseString objectFromJSONString];
    NSArray *currentIndexArray = [responseDict objectForKey:@"index"];
    id current = [responseDict objectForKey:@"current"];
    
    // Store versions as strings, but if they come off the wire as numbers, then handle that too
    if ([current isKindOfClass:[NSNumber class]])
        current = [NSString stringWithFormat:@"%ld", (long)[current integerValue]];
    self.pendingLastChangeSignature = [current length] > 0 ? [NSString stringWithFormat:@"%@", current] : nil;
    self.nextMark = [responseDict objectForKey:@"mark"];
    numTransfers--;
    
    // Remember all the retrieved data in case there's more to get
    [self.indexArray addObjectsFromArray:currentIndexArray];
    
    // If there aren't any instances remotely, just start getting changes
    if ([self.indexArray count] == 0) {
        gettingVersions = NO;
        [[self class] updateNetworkActivityIndictator];
        [self allVersionsFinished: nil];
        return;
    }
    
    // If there's another page, get those too (this will repeat until there are none left)
    if (self.nextMark.length > 0) {
        DDLogVerbose(@"Simperium found another index page mark (%@): %@", bucket.name, self.nextMark);
        [self requestLatestVersionsMark:self.nextMark];
        return;
    }

    // Index retrieval is complete, so get all the versions
    [self getVersionsForKeys:self.indexArray];
    [self.indexArray removeAllObjects];
}

-(void)processBatch {
    if ([self.responseBatch count] == 0)
        return;
    
    NSMutableArray *batch = [self.responseBatch copy];
    BOOL firstSync = bucket.lastChangeSignature == nil;
    dispatch_async(bucket.processorQueue, ^{
        if (started) {
            [bucket.indexProcessor processVersions: batch bucket:bucket firstSync: firstSync changeHandler:^(NSString *key) {
                // Local version was different, so process it as a local change
                [bucket.changeProcessor processLocalObjectWithKey:key bucket:bucket later:YES];
            }];
        }
    });
    
    [self.responseBatch removeAllObjects];
}

-(NSString *)keyFromUrl:(NSURL *)url {
    NSString *key = [[url pathComponents] objectAtIndex:5]; // 0:/ 1:apiversion 2:app 3:bucket 4:i 5:id 6: v 7:version
    
    // Hack for sharing, where the key can be id1/id2 (with a / character)
    BOOL fullyQualified = [[url pathComponents] count] == 9;
    
    if (fullyQualified) {
        NSString *key2 = [[url pathComponents] objectAtIndex:6];
        key = [key stringByAppendingFormat:@"/%@", key2];
    }

    return key;
}

-(void)getVersionFinished:(ASIHTTPRequest *)request
{
    gettingVersions = NO;
    NSURL *url = [request originalURL];
    NSString *responseString = [request responseString];
    
    numTransfers--;
    [[self class] updateNetworkActivityIndictator];
    
    if ([request responseStatusCode] != 200 || [[url pathComponents] count] < 6) {
        [self getVersionFailed:request];
        return;
    }
    
    DDLogDebug(@"Simperium received version (%@) code %d: %@", bucket.name, [request responseStatusCode], responseString);
    DDLogDebug(@"  (url was %@)", [url absoluteString]);
        
    NSString *version = [[request responseHeaders] objectForKey:@"X-Simperium-Version"];
    NSString *key = [self keyFromUrl: url];
    
    // If there was an error previously, unflag it
    [self.versionsWithErrors removeObjectForKey:key];    
    
    // Marshal stuff into an array for later processing
    NSArray *responseData = [NSArray arrayWithObjects: key, responseString, version, nil];
    [self.responseBatch addObject:responseData];
    
    // Batch responses for more efficient processing
    // (process the last handful individually though)
    if (numTransfers < INDEX_BATCH_SIZE || [self.responseBatch count] % INDEX_BATCH_SIZE == 0)
        [self processBatch];
}

-(void)getVersionFailed:(ASIHTTPRequest *)request {
    NSURL *url = [request originalURL];
    DDLogWarn(@"Simperium failed to retrieve version (%d): %@",[request responseStatusCode], url);
    NSString *version = [url lastPathComponent];
        
    NSString *key = [self keyFromUrl:url];
    
    numTransfers--;
    [[self class] updateNetworkActivityIndictator];

    if (version == nil || key == nil) {
        DDLogError(@"Simperium error: nil version/key during version retrieval (%@)", bucket.name);
        return;
    }
    
    [self.versionsWithErrors setObject:version forKey:key];    
}

-(void)indexQueueFinished:(ASINetworkQueue *)networkQueue
{
    if (self.nextMark.length > 0)
        // More index pages to get
        [self requestLatestVersionsMark:self.nextMark];
    else
        // The entire index has been retrieved
        [self allVersionsFinished:networkQueue];
}

-(void)allVersionsFinished:(ASINetworkQueue *)networkQueue
{
    [self processBatch];
    [self resetRetryDelay];

    DDLogVerbose(@"Simperium finished processing all objects from index (%@)", bucket.name);
    
    // Save it now that all versions are fetched; it improves performance to wait until this point
    //[simperium saveWithoutSyncing];
    
    if ([self.versionsWithErrors count] > 0) {
        // Try the index refresh again; this could be more efficient since we could know which version requests
        // failed, but it should happen rarely so take the easy approach for now
        DDLogWarn(@"Index refresh complete (%@) but %lu versions didn't load, retrying...", bucket.name, (unsigned long)[self.versionsWithErrors count]);
        
        // Create an array in the expected format
        NSMutableArray *errorArray = [NSMutableArray arrayWithCapacity: [self.versionsWithErrors count]];
        for (NSString *key in [self.versionsWithErrors allKeys]) {
            id errorVersion = [self.versionsWithErrors objectForKey:key];
            NSDictionary *versionDict = [NSDictionary dictionaryWithObjectsAndKeys:errorVersion, @"v",
                                                                                   key, @"id", nil];
            [errorArray addObject:versionDict];
        }
        [self performSelector:@selector(getVersionsForKeys:) withObject: errorArray afterDelay:1];
        //[self performSelector:@selector(requestLatestVersions) withObject:nil afterDelay:10];
        return;
    }
    
    // All versions were received successfully, so update the lastChangeSignature
    [bucket setLastChangeSignature:pendingLastChangeSignature];
    self.pendingLastChangeSignature = nil;
    
    gettingVersions = NO;
    
    // There could be some processing happening on the queue still, so don't start until they're done
    // Fake a network transfer so the progress indicator stays up until completion
    numTransfers += 1;
    [[self class] updateNetworkActivityIndictator];
    dispatch_async(bucket.processorQueue, ^{
        if (started) {
            dispatch_async(dispatch_get_main_queue(), ^{
                numTransfers -= 1;
                [[self class] updateNetworkActivityIndictator];
                DDLogInfo(@"Simperium finished processing index for %@", self.bucket.name);
                if ([bucket.delegate respondsToSelector:@selector(bucketDidFinishIndexing:)])
                    [bucket.delegate bucketDidFinishIndexing:bucket];

                [self startProcessingChanges];
            });
        } else dispatch_async(dispatch_get_main_queue(), ^{
            numTransfers = 0;
            [[self class] updateNetworkActivityIndictator];
        });
    });
}

-(void)getIndexFailed:(ASIHTTPRequest *)request
{
    if ([request responseStatusCode] == 401) {
        // User credentials changed
        [self authenticationDidFail];
    }

    gettingVersions = NO;
    int retry = [self nextRetryDelay];
    DDLogWarn(@"Simperium warning: couldn't get index, will retry in %d seconds (%@): %d - %@", retry, bucket.name, [request responseStatusCode], [request responseString]);
    numTransfers--;
    [[self class] updateNetworkActivityIndictator];
    
    [self performSelector:@selector(requestLatestVersionsForBucket:) withObject:self.bucket afterDelay:retry];
}


#pragma mark Versions
-(void)requestVersions:(int)numVersions object:(id<SPDiffable>)object
{
    // Get all the latest versions
    ASINetworkQueue *networkQueue = [ASINetworkQueue queue];
    [networkQueue setDelegate:self];
    [networkQueue setQueueDidFinishSelector:@selector(allObjectVersionsFinished:)];
    [networkQueue setRequestDidFinishSelector:@selector(getObjectVersionFinished:)];
    [networkQueue setRequestDidFailSelector:@selector(getObjectVersionFailed:)];
    
    DDLogInfo(@"Simperium enqueuing %d version requests for %@ (%@)", numVersions, [object simperiumKey], bucket.name);
    
    NSInteger startVersion = [object.ghost.version integerValue]-1;
    for (NSInteger i=startVersion; i>=1 && i>=startVersion-numVersions; i--) {
        NSString *versionStr = [NSString stringWithFormat:@"%ld", (long)i];
        ASIHTTPRequest *versionRequest = [self getRequestForKey:[object simperiumKey] version:versionStr];
        if (!versionRequest)
            return;
#if TARGET_OS_IPHONE
        versionRequest.shouldContinueWhenAppEntersBackground = YES;
#endif
        DDLogDebug(@"Simperium enqueuing version request (%@): %@", bucket.name, [[versionRequest url] absoluteString]);
        numTransfers++;
        [networkQueue addOperation:versionRequest];
    }
            
    [networkQueue go];
}

-(void)getObjectVersionFinished:(ASIHTTPRequest *)request
{
    gettingVersions = NO;
    NSURL *url = [request originalURL];
    NSString *responseString = [request responseString];
    DDLogDebug(@"Simperium received object version (%@) code %d: %@", bucket.name, [request responseStatusCode], responseString);
    DDLogDebug(@"  (url was %@)", [url absoluteString]);
    
    numTransfers--;
    [[self class] updateNetworkActivityIndictator];
    
    if ([request responseStatusCode] != 200) {
        DDLogWarn(@"Simperium failed to retrieve object version");
        return;
    }
    
    // lastPathComponent is > iOS 4.0, so deconstruct it manually for now
    //NSString *version = [url lastPathComponent];
    //NSString *key = [[url URLByDeletingLastPathComponent] lastPathComponent];
    NSString *urlString = [url absoluteString];
    NSArray *urlComponents = [urlString componentsSeparatedByString:@"/"];
    NSString *version = [urlComponents lastObject];
    NSString *key = [urlComponents objectAtIndex:[urlComponents count] - 3];
    
    NSDictionary *memberData = [responseString objectFromJSONStringWithParseOptions:JKParseOptionLooseUnicode];
    
    if ([bucket.delegate respondsToSelector:@selector(bucket:didReceiveObjectForKey:version:data:)])
        [bucket.delegate bucket:bucket didReceiveObjectForKey:key version:version data:memberData];
}


-(void)allObjectVersionsFinished:(ASINetworkQueue *)networkQueue
{
    DDLogInfo(@"Simperium finished retrieving all versions");
}

-(void)getObjectVersionFailed:(ASIHTTPRequest *)request
{
    gettingVersions = NO;
    DDLogWarn(@"Simperium warning: couldn't get object versions (%@): %d - %@", bucket.name, [request responseStatusCode], [request responseString]);
}

#pragma mark Sharing

-(void)shareObject:(id<SPDiffable>)object withEmail:(NSString *)email
{
    NSURL *url = [NSURL URLWithString:[simperium.appURL stringByAppendingFormat:@"%@/i/%@/share/%@", remoteBucketName,
                                       [object simperiumKey], email]];
    
    DDLogVerbose(@"Simperium sharing object: %@", url);

    ASIHTTPRequest *shareRequest = [ASIHTTPRequest requestWithURL:url];
    numTransfers++;
    [[self class] updateNetworkActivityIndictator];
    
    [shareRequest addRequestHeader:@"X-Simperium-Token" value:[simperium.user authToken]];
    NSDictionary *postData = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:TRUE] forKey:@"write_access"];
    NSString *jsonStr = [postData JSONString];
    [shareRequest appendPostData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding]];
    [shareRequest setDelegate:self];
    [shareRequest setDidFinishSelector:@selector(shareFinished:)];
    [shareRequest setDidFailSelector:@selector(shareFailed:)];
#if TARGET_OS_IPHONE
    shareRequest.shouldContinueWhenAppEntersBackground = YES;
#endif
    [shareRequest startAsynchronous];

}

-(NSString *)objectKeyFromShareRequest:(ASIHTTPRequest *)request {
    NSUInteger keyIndex = [[[request originalURL] pathComponents] count] - 3;
    NSString *key = [[[request originalURL] pathComponents] objectAtIndex:keyIndex];
    return key;
}

-(void)shareFailed:(ASIHTTPRequest *)request
{
    DDLogWarn(@"Simperium sharing failed (%d): %@", [request responseStatusCode], [request responseString]);
    
    if ([request responseStatusCode] == 404 || [request responseStatusCode] == 0) {
        // Try again, it might not have been created yet
        NSString *email = [[request originalURL] lastPathComponent];
        NSString *key = [self objectKeyFromShareRequest:request];
        DDLogWarn(@"Simperium retrying sharing of %@ with %@", key, email);
        id<SPDiffable> object = [self.bucket objectForKey:key];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self shareObject:object withEmail:email];
        });
    }
    numTransfers--;
    [[self class] updateNetworkActivityIndictator];
}

-(void)shareFinished:(ASIHTTPRequest *)request
{
    numTransfers--;
    [[self class] updateNetworkActivityIndictator];
    
    if ([request responseStatusCode] != 200) {
        [self shareFailed:request];
        return;
    }
    if ([bucket.delegate respondsToSelector:@selector(bucket:didShareObjectForKey:withEmail:)]) {
        NSString *email = [[request originalURL] lastPathComponent];
        NSString *key = [self objectKeyFromShareRequest:request];
        [bucket.delegate bucket:bucket didShareObjectForKey:key withEmail:email];
    }
    DDLogVerbose(@"Simperium sharing successful");
}


@end
