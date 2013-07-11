//
//  SPWebSocketChannel.m
//  Simperium
//
//  Created by Michael Johnston on 12-08-09.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPWebSocketChannel.h"

#define DEBUG_REQUEST_STATUS
#import "SPEnvironment.h"
#import "Simperium.h"
#import "SPDiffer.h"
#import "SPBucket.h"
#import "SPStorage.h"
#import "SPUser.h"
#import "SPChangeProcessor.h"
#import "SPIndexProcessor.h"
#import "SPMember.h"
#import "SPGhost.h"
#import "SPWebSocketChannel.h"
#import "SPWebSocketInterface.h"
#import "JSONKit.h"
#import "NSString+Simperium.h"
#import "DDLog.h"
#import "DDLogDebug.h"
#import <objc/runtime.h>
#import "SRWebSocket.h"

#define INDEX_PAGE_SIZE 500
#define INDEX_BATCH_SIZE 10
#define INDEX_QUEUE_SIZE 5

#define CHAN_NUMBER_INDEX 0
#define CHAN_COMMAND_INDEX 1
#define CHAN_DATA_INDEX 2


static BOOL useNetworkActivityIndicator = 0;
static int ddLogLevel = LOG_LEVEL_INFO;

@interface SPWebSocketChannel()
@property (nonatomic, weak) Simperium *simperium;
@property (nonatomic, strong) NSMutableArray *responseBatch;
@property (nonatomic, strong) NSMutableDictionary *versionsWithErrors;
@property (nonatomic, copy) NSString *clientID;
@end

@implementation SPWebSocketChannel
@synthesize simperium;
@synthesize webSocketManager;
@synthesize responseBatch;
@synthesize versionsWithErrors;
@synthesize nextMark;
@synthesize indexArray;
@synthesize clientID;
@synthesize pendingLastChangeSignature;
@synthesize started;
@synthesize name;
@synthesize number;

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

+ (void)updateNetworkActivityIndictator {
    // For now at least, don't display the indicator when using WebSockets
}

+ (void)setNetworkActivityIndicatorEnabled:(BOOL)enabled {
    useNetworkActivityIndicator = enabled;
}

- (id)initWithSimperium:(Simperium *)s clientID:(NSString *)cid {
	if ((self = [super init])) {
        self.simperium = s;
        self.indexArray = [NSMutableArray arrayWithCapacity:200];
        self.clientID = cid;
        self.versionsWithErrors = [NSMutableDictionary dictionaryWithCapacity:3];
    }
	
	return self;
}

- (void)sendChangesForBucket:(SPBucket *)bucket onlyQueuedChanges:(BOOL)onlyQueuedChanges completionBlock:(void(^)())completionBlock {
    // This gets called after remote changes have been handled in order to pick up any local changes that happened in the meantime
    dispatch_async(bucket.processorQueue, ^{
        NSArray *changes = [bucket.changeProcessor processPendingChanges:bucket onlyQueuedChanges:onlyQueuedChanges];
        if ([changes count] == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionBlock)
                    completionBlock();
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (started) {
                DDLogVerbose(@"Simperium sending all changes (%lu) for bucket %@", (unsigned long)[changes count], bucket.name);
                for (NSString *change in changes) {
                    NSString *jsonStr = [change JSONString];
                    NSString *message = [NSString stringWithFormat:@"%d:c:%@", number, jsonStr];
                    DDLogVerbose(@"Simperium sending change (%@-%@) %@",bucket.name, bucket.instanceLabel, message);
                    [self.webSocketManager send:message];
                }
                if (completionBlock)
                    completionBlock();
            }
        });
    });
}

- (void)sendChange:(NSDictionary *)change forKey:(NSString *)key bucket:(SPBucket *)bucket {
    DDLogVerbose(@"Simperium adding pending change (%@): %@", self.name, key);
    
    [bucket.changeProcessor processLocalChange:change key:key];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *jsonStr = [change JSONString];
        NSString *message = [NSString stringWithFormat:@"%d:c:%@", number, jsonStr];
        DDLogVerbose(@"Simperium sending change (%@-%@) %@",bucket.name, bucket.instanceLabel, message);
        [self.webSocketManager send:message];
    });
}

- (void)sendObjectDeletion:(id<SPDiffable>)object {
    NSString *key = [object simperiumKey];
    DDLogVerbose(@"Simperium sending entity DELETION change: %@/%@", self.name, key);
    
    // Send the deletion change (which will also overwrite any previous unsent local changes)
    // This could cause an ACK to fail if the deletion is registered before a previous change was ACK'd, but that should be OK since the object will be deleted anyway.
    
    if (key == nil) {
        DDLogWarn(@"Simperium received DELETION request for nil key");
        return;
    }
    
    dispatch_async(object.bucket.processorQueue, ^{
        NSDictionary *change = [object.bucket.changeProcessor processLocalDeletionWithKey: key];
        [self sendChange: change forKey: key bucket:object.bucket];
    });
}

- (void)sendObjectChanges:(id<SPDiffable>)object {
    // Consider being more careful about faulting here (since only the simperiumKey is needed)
    NSString *key = [object simperiumKey];
    if (key == nil) {
        DDLogWarn(@"Simperium tried to send changes for an object with a nil simperiumKey (%@)", self.name);
        return;
    }
    
    dispatch_async(object.bucket.processorQueue, ^{
        NSDictionary *change = [object.bucket.changeProcessor processLocalObjectWithKey:key bucket:object.bucket later:indexing || !started];
        if (change)
            [self sendChange: change forKey: key bucket:object.bucket];
    });
}

- (void)startProcessingChangesForBucket:(SPBucket *)bucket {
    __block int numChangesPending;
    __block int numKeysForObjectsWithMoreChanges;
    dispatch_async(bucket.processorQueue, ^{
        if (started) {
            numChangesPending = [bucket.changeProcessor numChangesPending];
            numKeysForObjectsWithMoreChanges = [bucket.changeProcessor numKeysForObjectsWithMoreChanges];

            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *getMessage = [NSString stringWithFormat:@"%d:cv:%@", number, bucket.lastChangeSignature ? bucket.lastChangeSignature : @""];
                if (numChangesPending > 0 || numKeysForObjectsWithMoreChanges > 0) {
                    // Send the offline changes
                    DDLogVerbose(@"Simperium sending %u pending offline changes (%@) plus %d objects with more", numChangesPending, self.name, numKeysForObjectsWithMoreChanges);
                    [self sendChangesForBucket:bucket onlyQueuedChanges:NO completionBlock:^{
                        // Start getting changes after all pending local changes have been sent
                        DDLogVerbose(@"Simperium client %@ sending cv %@", simperium.clientID, getMessage);
                        [self.webSocketManager send:getMessage];
                        
                    }];
                } else {
                    // No pending local changes, start getting changes right away
                    DDLogVerbose(@"Simperium client %@ sending cv %@", simperium.clientID, getMessage);
                    [self.webSocketManager send:getMessage];
                }
            });
        }
    });
}

- (int)nextRetryDelay {
//    int currentDelay = retryDelay;
//    retryDelay *= 2;
//    if (retryDelay > 24)
//        retryDelay = 24;
    
//    return currentDelay;
    return 2;
}

- (void)resetRetryDelay {
    retryDelay = 2;
}

- (void)handleRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket {
    // Changing entities and saving the context will clear Core Data's updatedObjects. Stash them so
    // sync will still work for any unsaved changes.
    [bucket.storage stashUnsavedObjects];
    
    dispatch_async(bucket.processorQueue, ^{
        if (started) {
            [bucket.changeProcessor processRemoteChanges:changes bucket:bucket clientID:clientID];
            dispatch_async(dispatch_get_main_queue(), ^{
                // After remote changes have been processed, check to see if any local changes were attempted (and
                // queued) in the meantime, and send them
                [self sendChangesForBucket:bucket onlyQueuedChanges:YES completionBlock:nil];
            });
        }
    });
}

#pragma mark Index handling

- (void)requestLatestVersionsForBucket:(SPBucket *)bucket mark:(NSString *)mark {
    if (!simperium.user) {
        DDLogError(@"Simperium critical error: tried to retrieve index with no user set");
        return;
    }
    //
    //    // Don't get changes while processing an index
    //    if ([getRequest isExecuting]) {
    //        DDLogVerbose(@"Simperium cancelling get request to retrieve index");
    //        [getRequest clearDelegatesAndCancel];
    //    }
    //
    //    // Get an index of all objects and fetch their latest versions
    indexing = YES;
    
    NSString *message = [NSString stringWithFormat:@"%d:i::%@::%d", number, mark ? mark : @"", INDEX_PAGE_SIZE];
    DDLogVerbose(@"Simperium requesting index (%@): %@", self.name, message);
    [self.webSocketManager send:message];
}

-(void)requestLatestVersionsForBucket:(SPBucket *)bucket {
    // Multiple errors could try to trigger multiple index refreshes
    if (indexing)
        return;
    
    // Send any pending changes first
    // This could potentially lead to some duplicate changes being sent if there are some that are awaiting
    // acknowledgment, but the server will safely ignore them
    [self sendChangesForBucket:bucket onlyQueuedChanges:NO completionBlock: ^{
        [self requestLatestVersionsForBucket:bucket mark:nil];
    }];
}

- (void)requestVersionsForKeys:(NSArray *)currentIndexArray bucket:(SPBucket *)bucket {
    // Changing entities and saving the context will clear Core Data's updatedObjects. Stash them so
    // sync will still work later for any unsaved changes.
    // In the time between now and when the index refresh completes, any local changes will get marked
    // since regular syncing is disabled during index retrieval.
    [bucket.storage stashUnsavedObjects];

    if ([bucket.delegate respondsToSelector:@selector(bucketWillStartIndexing:)])
        [bucket.delegate bucketWillStartIndexing:bucket];

    self.responseBatch = [NSMutableArray arrayWithCapacity:INDEX_BATCH_SIZE];

    // Get all the latest versions
    DDLogInfo(@"Simperium processing %lu objects from index (%@)", (unsigned long)[currentIndexArray count], self.name);

    NSArray *indexArrayCopy = [currentIndexArray copy];
    __block int objectRequests = 0;
    dispatch_async(bucket.processorQueue, ^{
        if (started) {
            [bucket.indexProcessor processIndex:indexArrayCopy bucket:bucket versionHandler: ^(NSString *key, NSString *version) {
                objectRequests++;

                // For each version that is processed, create a network request
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *message = [NSString stringWithFormat:@"%d:e:%@.%@", number, key, version];
                    DDLogVerbose(@"Simperium sending object request (%@): %@", self.name, message);
                    [self.webSocketManager send:message];
                });
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                // If no requests need to be queued, then all is good; back to processing
                objectVersionsPending = objectRequests;
                if (objectVersionsPending == 0) {
                    if (self.nextMark.length > 0)
                    // More index pages to get
                        [self requestLatestVersionsForBucket: bucket mark:self.nextMark];
                    else
                    // The entire index has been retrieved
                        [self allVersionsFinishedForBucket:bucket];
                    return;
                }

                DDLogInfo(@"Simperium enqueuing %d object requests (%@)", objectVersionsPending, bucket.name);
            });
        }
    });
}

- (void)handleIndexResponse:(NSString *)responseString bucket:(SPBucket *)bucket {
    DDLogVerbose(@"Simperium received index (%@): %@", self.name, responseString);
    NSDictionary *responseDict = [responseString objectFromJSONString];
    NSArray *currentIndexArray = [responseDict objectForKey:@"index"];
    id current = [responseDict objectForKey:@"current"];

    // Store versions as strings, but if they come off the wire as numbers, then handle that too
    if ([current isKindOfClass:[NSNumber class]])
        current = [NSString stringWithFormat:@"%ld", (long)[current integerValue]];
    self.pendingLastChangeSignature = [current length] > 0 ? [NSString stringWithFormat:@"%@", current] : nil;
    self.nextMark = [responseDict objectForKey:@"mark"];
    
    // Remember all the retrieved data in case there's more to get
    [self.indexArray addObjectsFromArray:currentIndexArray];

    // If there aren't any instances remotely, just start getting changes
    if ([self.indexArray count] == 0) {
        [self allVersionsFinishedForBucket:bucket];
        return;
    }

    // If there's another page, get those too (this will repeat until there are none left)
    if (self.nextMark.length > 0) {
        DDLogVerbose(@"Simperium found another index page mark (%@): %@", self.name, self.nextMark);
        [self requestLatestVersionsForBucket:bucket mark:self.nextMark];
        return;
    }

    // Index retrieval is complete, so get all the versions
    [self requestVersionsForKeys:self.indexArray bucket:bucket];
    [self.indexArray removeAllObjects];
}

- (void)processBatchForBucket:(SPBucket *)bucket {
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
            
            // Now check if indexing is complete
            dispatch_async(dispatch_get_main_queue(), ^{
                if (objectVersionsPending > 0)
                    objectVersionsPending--;
                if (objectVersionsPending == 0)
                    [self allVersionsFinishedForBucket:bucket];
            });
        }
    });

    [self.responseBatch removeAllObjects];
}

- (void)handleVersionResponse:(NSString *)responseString bucket:(SPBucket *)bucket {
    if ([responseString isEqualToString:@"?"]) {
        DDLogError(@"Simperium error: version not found during version retrieval (%@)", bucket.name);
        return;
    }

    NSRange range = [responseString rangeOfString:@"."];
    NSString *key = [responseString substringToIndex:range.location];
    NSString *versionString = [responseString substringFromIndex:range.location+range.length];
    range = [versionString rangeOfString:@"\n"];
    NSString *version = [versionString substringToIndex:range.location];
    versionString = [versionString substringFromIndex:range.location + range.length];
    DDLogDebug(@"Simperium received version (%@): %@", self.name, responseString);
    
    // With websockets, the data is wrapped in a dictionary, so unwrap it
    // This processing should be moved off the main thread (or fixed at the protocol level)
    NSDictionary *versionDict = [versionString objectFromJSONString];
    NSDictionary *dataDict = [versionDict objectForKey:@"data"];
    versionString = [dataDict JSONString];
    
    // If there was an error previously, unflag it
    [self.versionsWithErrors removeObjectForKey:key];

    // If retrieving object versions (e.g. for going back in time), return the result directly to the delegate
    if (retrievingObjectHistory) {
        if ([bucket.delegate respondsToSelector:@selector(bucket:didReceiveObjectForKey:version:data:)])
            [bucket.delegate bucket:bucket didReceiveObjectForKey:key version:version data:dataDict];
    } else {
        // Otherwise, process the result for indexing
        // Marshal stuff into an array for later processing
        NSArray *responseData = [NSArray arrayWithObjects: key, versionString, version, nil];
        [self.responseBatch addObject:responseData];

        // Batch responses for more efficient processing
        // (process the last handful individually though)
        if ([self.responseBatch count] < INDEX_BATCH_SIZE || [self.responseBatch count] % INDEX_BATCH_SIZE == 0)
            [self processBatchForBucket:bucket];
    }
}

- (void)allVersionsFinishedForBucket:(SPBucket *)bucket {
    [self processBatchForBucket:bucket];
    [self resetRetryDelay];

    DDLogVerbose(@"Simperium finished processing all objects from index (%@)", self.name);

    // Save it now that all versions are fetched; it improves performance to wait until this point
    //[simperium saveWithoutSyncing];

    if ([self.versionsWithErrors count] > 0) {
        // Try the index refresh again; this could be more efficient since we could know which version requests
        // failed, but it should happen rarely so take the easy approach for now
        DDLogWarn(@"Index refresh complete (%@) but %lu versions didn't load, retrying...", self.name, (unsigned long)[self.versionsWithErrors count]);

        // Create an array in the expected format
        NSMutableArray *errorArray = [NSMutableArray arrayWithCapacity: [self.versionsWithErrors count]];
        for (NSString *key in [self.versionsWithErrors allKeys]) {
            id errorVersion = [self.versionsWithErrors objectForKey:key];
            NSDictionary *versionDict = [NSDictionary dictionaryWithObjectsAndKeys:errorVersion, @"v",
                                                                                   key, @"id", nil];
            [errorArray addObject:versionDict];
        }
        [self performSelector:@selector(requestVersionsForKeys:) withObject: errorArray afterDelay:1];
        //[self performSelector:@selector(requestLatestVersions) withObject:nil afterDelay:10];
        return;
    }

    // All versions were received successfully, so update the lastChangeSignature
    [bucket setLastChangeSignature:pendingLastChangeSignature];
    self.pendingLastChangeSignature = nil;
    self.nextMark = nil;
    indexing = NO;

    // There could be some processing happening on the queue still, so don't start until they're done
    dispatch_async(bucket.processorQueue, ^{
        if (started) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([bucket.delegate respondsToSelector:@selector(bucketDidFinishIndexing:)])
                    [bucket.delegate bucketDidFinishIndexing:bucket];

                [self startProcessingChangesForBucket:bucket];
            });
        }
    });
}
//
//-(void)getIndexFailed:(ASIHTTPRequest *)request
//{
//    gettingVersions = NO;
//    int retry = [self nextRetryDelay];
//    DDLogWarn(@"Simperium warning: couldn't get index, will retry in %d seconds (%@): %d - %@", retry, bucket.name, [request responseStatusCode], [request responseString]);
//    numTransfers--;
//    [[self class] updateNetworkActivityIndictator];
//
//    [self performSelector:@selector(requestLatestVersions) withObject:nil afterDelay:retry];
//}

#pragma mark Object Versions
- (void)requestVersions:(int)numVersions object:(id<SPDiffable>)object {
    // If already retrieving versions on this channel, don't do it again
    if (retrievingObjectHistory)
        return;
    
    retrievingObjectHistory = YES;
    objectVersionsPending = numVersions;
    
    NSInteger startVersion = [object.ghost.version integerValue]-1;
    for (NSInteger i=startVersion; i>=1 && i>=startVersion-numVersions; i--) {
        NSString *versionStr = [NSString stringWithFormat:@"%ld", (long)i];
        NSString *message = [NSString stringWithFormat:@"%d:e:%@.%@", number, object.simperiumKey, versionStr];
        DDLogVerbose(@"Simperium sending object version request (%@): %@", self.name, message);
        [self.webSocketManager send:message];
    }
}


#pragma mark Sharing

- (void)shareObject:(id<SPDiffable>)object withEmail:(NSString *)email {
    // Not yet implemented with WebSockets
}

@end


