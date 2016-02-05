//
//  SPWebSocketChannel.m
//  Simperium
//
//  Created by Michael Johnston on 12-08-09.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPWebSocketChannel.h"

#import "SPEnvironment.h"
#import "Simperium+Internals.h"
#import "SPDiffer.h"
#import "SPBucket+Internals.h"
#import "SPStorage.h"
#import "SPUser.h"
#import "SPChangeProcessor.h"
#import "SPIndexProcessor.h"
#import "SPMember.h"
#import "SPGhost.h"
#import "SPWebSocketInterface.h"
#import "JSONKit+Simperium.h"
#import "NSString+Simperium.h"
#import "SPLogger.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

typedef NS_ENUM(NSInteger, SPWebsocketAuthError) {
    SPWebsocketAuthErrorTokenMalformed                      = 400,
    SPWebsocketAuthErrorTokenInvalid                        = 401
};

static int const SPWebsocketMaxPendingVersions              = 200;
static int const SPWebsocketChangesBatchSize                = 20;
static int const SPWebsocketIndexPageSize                   = 500;
static int const SPWebsocketIndexBatchSize                  = 20;
static NSString* const SPWebsocketErrorMark                 = @"{";
static NSString* const SPWebsocketErrorCodeKey              = @"code";
static NSTimeInterval const SPWebSocketSyncTimeoutInterval  = 180;

static SPLogLevels logLevel                                 = SPLogLevelsInfo;

typedef void(^SPWebSocketSyncedBlockType)(void);


#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPWebSocketChannel()
@property (nonatomic,   weak) Simperium                     *simperium;
@property (nonatomic, strong) NSTimer                       *syncTimeoutTimer;
@property (nonatomic, strong) NSMutableArray                *versionsBatch;
@property (nonatomic, strong) NSMutableArray                *changesBatch;
@property (nonatomic, strong) NSMutableDictionary           *versionsPending;
@property (nonatomic, assign) NSInteger                     objectVersionsPending;
@property (nonatomic, assign) BOOL                          started;
@property (nonatomic, assign) BOOL                          indexing;
@property (nonatomic, assign) BOOL                          retrievingObjectHistory;
@property (nonatomic, assign) BOOL                          shouldSendEverything;
@property (nonatomic,   copy) SPWebSocketSyncedBlockType    onLocalChangesSent;
@end


#pragma mark ====================================================================================
#pragma mark SPWebSocketChannel
#pragma mark ====================================================================================

@implementation SPWebSocketChannel

- (instancetype)initWithSimperium:(Simperium *)s {
    self = [super init];
    if (self) {
        _simperium          = s;
        _indexArray         = [NSMutableArray arrayWithCapacity:200];
        _changesBatch       = [NSMutableArray arrayWithCapacity:SPWebsocketChangesBatchSize];
        _versionsBatch      = [NSMutableArray arrayWithCapacity:SPWebsocketIndexBatchSize];
        _versionsPending    = [NSMutableDictionary dictionary];
    }
    
    return self;
}


#pragma mark ====================================================================================
#pragma mark Object Versions
#pragma mark ====================================================================================

- (void)requestVersions:(int)numVersions object:(id<SPDiffable>)object {
    // If already retrieving versions on this channel, don't do it again
    if (self.retrievingObjectHistory) {
        return;
    }
    
    self.retrievingObjectHistory = YES;
    
    NSInteger lastVersion   = [object.ghost.version integerValue];
    NSInteger firstVersion  = MAX(lastVersion - numVersions, 1);
    
    for (NSInteger version = lastVersion; version >= firstVersion; --version) {
        NSString *versionStr = [NSString stringWithFormat:@"%ld", (long)version];
        [self requestVersion:versionStr forObjectWithKey:object.simperiumKey];
    }
}

- (void)requestLatestVersionsForBucket:(SPBucket *)bucket {
    
    SPLogVerbose(@"Simperium change version is out of date (%@), re-indexing", bucket.name);
    
    // Multiple errors could try to trigger multiple index refreshes
    if (self.indexing) {
        return;
    }
    
    self.indexing = YES;

    // Send any pending changes first
    // This could potentially lead to some duplicate changes being sent if there are some that are awaiting
    // acknowledgment, but the server will safely ignore them
    [self setShouldSendEverything];
    
    [self sendChangesForBucket:bucket completionBlock: ^{
        [self requestLatestVersionsForBucket:bucket mark:nil];
    }];
}

- (void)requestVersion:(NSString *)version forObjectWithKey:(NSString *)simperiumKey {
    
    NSAssert([NSThread isMainThread], @"This method should get called on the main thread!");
    if (!version || !simperiumKey) {
        return;
    }
    
    ++_objectVersionsPending;
    
    // Hit the WebSocket
    SPLogVerbose(@"Simperium downloading entity (%@) %@.%@", self.name, simperiumKey, version);
    NSString *message = [NSString stringWithFormat:@"%d:e:%@.%@", self.number, simperiumKey, version];
    [self.webSocketManager send:message];
}

- (void)requestVersionsInBatch:(NSDictionary *)versions {
    
    NSAssert([NSThread isMainThread], @"This method should get called on the main thread!");

    [self.versionsPending addEntriesFromDictionary:versions];
    [self requestPendingVersionsIfNeeded];
}

- (void)requestPendingVersionsIfNeeded {
    
    NSAssert([NSThread isMainThread], @"This method should get called on the main thread!");
    
    NSMutableSet *requestedKeys = [NSMutableSet set];
  
    for (NSString *simperiumKey in self.versionsPending.allKeys) {
        if ([self reachedMaximumPendingVersions]) {
            break;
        }

        [self requestVersion:self.versionsPending[simperiumKey] forObjectWithKey:simperiumKey];
        [requestedKeys addObject:simperiumKey];
    }

    // Remember what's missing!
    [self.versionsPending removeObjectsForKeys:requestedKeys.allObjects];
}

- (BOOL)hasPendingVersionRequests {
    return self.versionsPending.count != 0;
}

- (BOOL)reachedMaximumPendingVersions {
    return self.objectVersionsPending > SPWebsocketMaxPendingVersions;
}


#pragma mark ====================================================================================
#pragma mark Sending Object Changes
#pragma mark ====================================================================================

- (void)sendObjectDeletion:(id<SPDiffable>)object {
    NSString *key       = object.simperiumKey;
    SPBucket *bucket    = object.bucket;
    if (key == nil) {
        SPLogWarn(@"Simperium received DELETION request for nil key");
        return;
    }

    // Send the deletion change (which will also overwrite any previous unsent local changes)
    // This could cause an ACK to fail if the deletion is registered before a previous change was ACK'd, but that should be OK since the object will be deleted anyway.
    //
    dispatch_async(object.bucket.processorQueue, ^{
        
        // AutoreleasePool:
        //  While processing large amounts of objects, memory usage will potentially ramp up if we don't add a pool here!
        @autoreleasepool {
            SPChangeProcessor *processor = object.bucket.changeProcessor;

            if (_indexing || !_authenticated || processor.reachedMaxPendings) {
                [processor enqueueObjectForDeletion:key bucket:bucket];
            } else {
                NSSet *wrappedKey   = [NSSet setWithObject:key];
                NSArray *changes    = [processor processLocalDeletionsWithKeys:wrappedKey];
                for (NSDictionary *change in changes) {
                    [self sendChange:change];
                }
            }
        }
    });
}

- (void)sendObjectChanges:(id<SPDiffable>)object {
    NSString *key       = object.simperiumKey;
    SPBucket *bucket    = object.bucket;
    if (key == nil) {
        SPLogWarn(@"Simperium tried to send changes for an object with a nil simperiumKey (%@)", self.name);
        return;
    }
    
    dispatch_async(object.bucket.processorQueue, ^{
        
        // AutoreleasePool:
        //  While processing large amounts of objects, memory usage will potentially ramp up if we don't add a pool here!
        @autoreleasepool {
            SPChangeProcessor *processor = object.bucket.changeProcessor;
            
            if (_indexing || !_authenticated || processor.reachedMaxPendings) {
                [processor enqueueObjectForMoreChanges:key bucket:bucket];
            } else {
                NSSet *wrappedKey = [NSSet setWithObject:key];
                NSArray *changes = [processor processLocalObjectsWithKeys:wrappedKey bucket:object.bucket];
                for (NSDictionary *change in changes) {
                    [self sendChange:change];
                }
            }
        }
    });
}

- (void)shareObject:(id<SPDiffable>)object withEmail:(NSString *)email {
    // Not yet implemented with WebSockets
}


#pragma mark ====================================================================================
#pragma mark Bucket Helpers
#pragma mark ====================================================================================

- (void)removeAllBucketObjects:(SPBucket *)bucket {
    NSSet *wrappedBucket = [NSSet setWithObject:bucket];
    NSArray *changes = [bucket.changeProcessor processLocalBucketsDeletion:wrappedBucket];
    
    for (NSDictionary *change in changes) {
        NSString *message = [NSString stringWithFormat:@"%d:c:%@", self.number, [change sp_JSONString]];
        SPLogVerbose(@"Simperium deleting all Bucket Objects (%@-%@) %@", bucket.name, bucket.instanceLabel, message);
        
        [self.webSocketManager send:message];
    }
}


#pragma mark ====================================================================================
#pragma mark Response Handlers
#pragma mark ====================================================================================

- (void)handleAuthResponse:(NSString *)responseString bucket:(SPBucket *)bucket {
    
    // Do we have any errors?
    if ([responseString rangeOfString:SPWebsocketErrorMark].location == 0) {
        SPLogWarn(@"Simperium received unexpected auth response: %@", responseString);
        
        NSError *error = nil;
        NSDictionary *authPayload = [responseString sp_objectFromJSONStringWithError:&error];
        
        if ([authPayload isKindOfClass:[NSDictionary class]]) {
            NSInteger errorCode = [authPayload[SPWebsocketErrorCodeKey] integerValue];
            if (errorCode == SPWebsocketAuthErrorTokenMalformed || errorCode == SPWebsocketAuthErrorTokenInvalid) {
                [[NSNotificationCenter defaultCenter] postNotificationName:SPAuthenticationDidFail object:self];
            }
        }
        return;
    }
    
    // All looking good!
    self.authenticated              = YES;
    self.started                    = NO;
    self.indexing                   = NO;
    self.retrievingObjectHistory    = NO;
    self.shouldSendEverything       = NO;
    self.simperium.user.email       = responseString;
    self.onLocalChangesSent         = nil;
    self.objectVersionsPending      = 0;
    
    [self.versionsPending removeAllObjects];
    
    // Reset disable-rebase mechanism + reset reload mechanism
    dispatch_async(bucket.processorQueue, ^{
        [bucket.indexProcessor enableRebaseForAllObjects];
        [bucket.indexProcessor disableReloadForAllObjects];
    });
    
    // Download the index, on the 1st sync
    if (bucket.lastChangeSignature == nil) {
        [self requestLatestVersionsForBucket:bucket];
    } else {
        [self startProcessingChangesForBucket:bucket];
    }
}

- (void)handleRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket {
    
    NSAssert([NSThread isMainThread], @"This should get called on the main thread!");
    
    // Batch-Processing:
    // This will speed up sync'ing of large databases. We should perform this OP in the processorQueue: numChangesPending gets updated there!
    dispatch_async(bucket.processorQueue, ^{
        [self.changesBatch addObjectsFromArray:changes];

        BOOL shouldProcess = (!_started || _changesBatch.count % SPWebsocketChangesBatchSize == 0 || bucket.changeProcessor.numChangesPending < SPWebsocketChangesBatchSize);
        if (!shouldProcess) {
            return;
        }
        
        NSArray *receivedBatch  = self.changesBatch;
        self.changesBatch       = [NSMutableArray arrayWithCapacity:SPWebsocketChangesBatchSize];
        self.started            = YES;
        
        [self processBatchChanges:receivedBatch bucket:bucket];
    });
    
    // Signal there's activity in the channel
    [self invalidateSyncTimeoutTimer];
}

- (void)processBatchChanges:(NSArray *)changes bucket:(SPBucket *)bucket {
    
    NSAssert([NSThread isMainThread] == false, @"This should NOT get called on the main thread!");
    
    SPLogVerbose(@"Simperium handling changes (%@) %@", bucket.name ,changes);
    
    SPChangeProcessor *changeProcessor  = bucket.changeProcessor;
    SPIndexProcessor *indexProcessor    = bucket.indexProcessor;
    __weak __typeof(self) weakSelf      = self;
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        // Changing entities and saving the context will clear Core Data's updatedObjects. Stash them so
        // sync will still work for any unsaved changes.
        [bucket.storage stashUnsavedObjects];
        
        // Notify the delegates on the main thread that we're about to apply remote changes
        [changeProcessor notifyOfRemoteChanges:changes bucket:bucket];
    });
    
    // Failsafe: Don't proceed if we just got deauthenticated
    if (!self.authenticated) {
        return;
    }
    
    // Process the changes!
    SPChangeSuccessHandlerBlockType successHandler = ^(NSString *simperiumKey, NSString *version) {
        
        [indexProcessor enableRebaseForObjectWithKey:simperiumKey];
    };
    
    SPChangeErrorHandlerBlockType errorHandler = ^(NSString *simperiumKey, NSString *version, NSError *error) {
        
        SPLogError(@"Simperium Error [%@] while processing changes for object [%@][%@]", error.localizedDescription, bucket.name, simperiumKey);
        
        if (error.code == SPProcessorErrorsClientOutOfSync) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf requestLatestVersionsForBucket:bucket];
            });
            
        } else if (error.code == SPProcessorErrorsSentDuplicateChange) {
            [changeProcessor discardPendingChanges:simperiumKey bucket:bucket];
            
        } else if (error.code == SPProcessorErrorsSentInvalidChange) {
            [changeProcessor enqueueObjectForRetry:simperiumKey bucket:bucket overrideRemoteData:YES];
            [indexProcessor disableRebaseForObjectWithKey:simperiumKey];
            
        } else if (error.code == SPProcessorErrorsServerError) {
            [changeProcessor enqueueObjectForRetry:simperiumKey bucket:bucket overrideRemoteData:NO];
            
        } else if (error.code == SPProcessorErrorsClientError) {
            [changeProcessor discardPendingChanges:simperiumKey bucket:bucket];
            
        } else if (error.code == SPProcessorErrorsReceivedInvalidChange) {
            // Prevent re-entrant calls: Indexing flag is modified only on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakSelf.indexing == false) {
                    [weakSelf requestVersion:version forObjectWithKey:simperiumKey];
                    return;
                }
                dispatch_async(bucket.processorQueue, ^{
                    [indexProcessor enableReloadForObjectWithKey:simperiumKey];
                });
            });
        }
    };
    
    [changeProcessor processRemoteChanges:changes bucket:bucket successHandler:successHandler errorHandler:errorHandler];
    

    //  After remote changes have been processed, check to see if any local changes were attempted (and queued)
    //  in the meantime, and send them.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendChangesForBucket:bucket];
    });
}

- (void)handleIndexResponse:(NSString *)responseString bucket:(SPBucket *)bucket {
    
    SPLogVerbose(@"Simperium received index (%@): %@", self.name, responseString);

    if (self.indexing == false) {
        SPLogError(@"ERROR: Index response was NOT expected!");
    }
    
    NSDictionary *responseDict      = [responseString sp_objectFromJSONString];
    NSArray *currentIndexArray      = responseDict[@"index"];
    NSString *current               = responseDict[@"current"];
    
    // Store versions as strings, but if they come off the wire as numbers, then handle that too
    if ([current isKindOfClass:[NSNumber class]]) {
        current = [NSString stringWithFormat:@"%ld", (long)[current integerValue]];
    }
    self.pendingLastChangeSignature = [current length] > 0 ? [NSString stringWithFormat:@"%@", current] : nil;
    self.nextMark                   = responseDict[@"mark"];
    
    // Remember all the retrieved data in case there's more to get
    [self.indexArray addObjectsFromArray:currentIndexArray];
    
    if (self.nextMark.length > 0) {
        // If there's another page, get those too (this will repeat until there are none left)
        SPLogVerbose(@"Simperium found another index page mark (%@): %@", self.name, self.nextMark);
        [self requestLatestVersionsForBucket:bucket mark:self.nextMark];
    } else {
        // Index retrieval is complete, so get all the versions
        [self requestVersionsForKeys:self.indexArray bucket:bucket];
        [self.indexArray removeAllObjects];
    }
}

- (void)handleVersionResponse:(NSString *)responseString bucket:(SPBucket *)bucket {
    NSAssert([NSThread isMainThread], @"This method should get called on the main thread");
    
    // Handle Error messages
    if ([responseString isEqualToString:@"?"]) {
        SPLogError(@"Simperium error: '?' response during version retrieval (%@)", bucket.name);
        _objectVersionsPending--;
        return;
    }
    
    // Expected format is: key_here.maybe.with.periods.VERSIONSTRING\n{payload}
    NSRange headerRange = [responseString rangeOfString:@"\n"];
    if (headerRange.location == NSNotFound) {
        SPLogError(@"Simperium error: version header not found during version retrieval (%@)", bucket.name);
        _objectVersionsPending--;
        return;
    }
    
    NSRange keyRange = [responseString rangeOfString:@"." options:NSBackwardsSearch range:NSMakeRange(0, headerRange.location)];
    if (keyRange.location == NSNotFound) {
        SPLogError(@"Simperium error: version key not found during version retrieval (%@)", bucket.name);
        _objectVersionsPending--;
        return;
    }
    
    NSRange versionRange = NSMakeRange(keyRange.location + keyRange.length,
                                       headerRange.location - headerRange.length - keyRange.location);
    
    NSString *key       = [responseString substringToIndex:keyRange.location];
    NSString *version   = [responseString substringWithRange:versionRange];
    NSString *payload   = [responseString substringFromIndex:headerRange.location + headerRange.length];
    SPLogVerbose(@"Simperium received version (%@): %@", self.name, responseString);
    
    // With websockets, the data is wrapped up (somewhat annoyingly) in a dictionary, so unwrap it
    // This processing should probably be moved off the main thread (or improved at the protocol level)
    NSDictionary *payloadDict   = [payload sp_objectFromJSONString];
    NSDictionary *dataDict      = payloadDict[@"data"];
    
    if ([dataDict class] == [NSNull class] || dataDict == nil) {
        // No data
        SPLogError(@"Simperium error: version had no data (%@): %@", bucket.name, key);
        _objectVersionsPending--;
        return;
    }
    
    if (_retrievingObjectHistory) {
        // If retrieving object versions (e.g. for going back in time), return the result directly to the delegate
        if (--_objectVersionsPending == 0) {
            _retrievingObjectHistory = NO;
        }
        if ([bucket.delegate respondsToSelector:@selector(bucket:didReceiveObjectForKey:version:data:)]) {
            [bucket.delegate bucket:bucket didReceiveObjectForKey:key version:version data:dataDict];
        }
    } else {
        // Otherwise, process the result for indexing
        // Marshal everything into an array for later processing
        NSArray *responseData = @[ key, version, dataDict ];
        [self.versionsBatch addObject:responseData];

        // Batch responses for more efficient processing
        if ((self.versionsBatch.count == self.objectVersionsPending && self.objectVersionsPending < SPWebsocketIndexBatchSize) ||
            (self.versionsBatch.count % SPWebsocketIndexBatchSize == 0))
        {
            [self processVersionsBatchForBucket:bucket];
        }
    }
}

- (void)handleOptions:(NSString *)options bucket:(SPBucket *)bucket {
    NSDictionary *optionsDict = [options sp_objectFromJSONString];
    
    bucket.localNamespace   = optionsDict[@"namespace"];
    bucket.exposeNamespace  = [optionsDict[@"expose_namespace"] boolValue];
}

- (void)handleIndexStatusRequest:(SPBucket *)bucket {
    
    NSDictionary *response = [bucket exportStatus];
    NSString *message = [NSString stringWithFormat:@"%d:index:%@", self.number, [response sp_JSONString]];
    
    SPLogVerbose(@"Simperium sending Bucket Internal State (%@-%@) %@", bucket.name, bucket.instanceLabel, message);
    [self.webSocketManager send:message];
}


#pragma mark ====================================================================================
#pragma mark Initialization
#pragma mark ====================================================================================

- (void)startProcessingChangesForBucket:(SPBucket *)bucket {

    NSAssert([NSThread isMainThread], @"This method should get called on the main thread");
        
    if (!self.authenticated) {
        return;
    }
    
    // Start getting changes from the last cv
    NSString *getMessage = [NSString stringWithFormat:@"%d:cv:%@", self.number, bucket.lastChangeSignature ? bucket.lastChangeSignature : @""];
    SPLogVerbose(@"Simperium client %@ sending cv %@", self.simperium.clientID, getMessage);
    [self.webSocketManager send:getMessage];

    // In the next changeset-handling cycle, let's send everything
    [self setShouldSendEverything];
}

- (void)stop {
    
    NSAssert([NSThread isMainThread], @"This method should get called on the main thread");
    
    self.authenticated = false;
    self.webSocketManager = nil;
    [self invalidateSyncTimeoutTimer];
}


#pragma mark ====================================================================================
#pragma mark Private Methods: Sending Changes
#pragma mark ====================================================================================

- (void)setShouldSendEverything {
    self.shouldSendEverything = YES;
}

- (void)sendChangesForBucket:(SPBucket *)bucket completionBlock:(SPWebSocketSyncedBlockType)completionBlock {

    NSAssert(self.onLocalChangesSent == nil, @"This method should not get called more than once, before completion");
    self.onLocalChangesSent = completionBlock;
    [self sendChangesForBucket:bucket];
}

- (void)sendChangesForBucket:(SPBucket *)bucket {
    
    if (!self.authenticated) {
        return;
    }
    
    // Note: 'onlyQueuedChanges' set to false will post **every** pending change, again
    BOOL onlyQueuedChanges              = !self.shouldSendEverything;
    SPChangeProcessor *processor        = bucket.changeProcessor;
    SPChangeEnumerationBlockType block  = ^(NSDictionary *change) {
        [self sendChange:change];
    };
    
    // This gets called after remote changes have been handled in order to pick up any local changes that happened in the meantime
    dispatch_async(bucket.processorQueue, ^{
        
        // AutoreleasePool:
        //  While processing large amounts of objects, memory usage will potentially ramp up if we don't add a pool here!
        @autoreleasepool {
            
            // Only queued: re-send failed changes
            if (onlyQueuedChanges) {
                [processor enumerateRetryChangesForBucket:bucket block:block];
                
            // Pending changes include those flagged for retry as well
            } else {
                [processor enumeratePendingChangesForBucket:bucket block:block];
            }
            
            // Process Queued Changes: let's consider the SPWebsocketMaxPendingChanges limit
            [processor enumerateQueuedChangesForBucket:bucket block:block];
            [processor enumerateQueuedDeletionsForBucket:bucket block:block];
            
            // Ready posting local changes. If needed, hit the callback
            if (!self.onLocalChangesSent) {
                return;
            }
            
            if (processor.numChangesPending || processor.numKeysForObjectsWithMoreChanges || processor.numKeysForObjectToDelete) {
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.onLocalChangesSent) {
                    self.onLocalChangesSent();
                    self.onLocalChangesSent = nil;
                }
            });
        }
    });
    
    // Already done
    self.shouldSendEverything = NO;
}

- (void)sendChange:(NSDictionary *)change {
    if (!change) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = [NSString stringWithFormat:@"%d:c:%@", self.number, [change sp_JSONString]];
        SPLogVerbose(@"Simperium sending change (%@-%@) %@", self.name, self.simperium.label, message);
        
        [self.webSocketManager send:message];
        [self startSyncTimeoutTimer];
    });
}


#pragma mark ====================================================================================
#pragma mark Private Methods: Index Handling
#pragma mark ====================================================================================

- (void)requestLatestVersionsForBucket:(SPBucket *)bucket mark:(NSString *)mark {
    if (!self.simperium.user) {
        SPLogError(@"Simperium critical error: tried to retrieve index with no user set");
        return;
    }

    // Get an index of all objects and fetch their latest versions
    self.indexing = YES;
    
    NSString *message = [NSString stringWithFormat:@"%d:i::%@::%d", self.number, mark ? mark : @"", SPWebsocketIndexPageSize];
    SPLogVerbose(@"Simperium requesting index (%@): %@", self.name, message);
    [self.webSocketManager send:message];
}

- (void)processVersionsBatchForBucket:(SPBucket *)bucket {
    // Request any pending versions, if needed
    [self requestPendingVersionsIfNeeded];
    
    if (self.versionsBatch.count == 0) {
        return;
    }
    
    NSMutableArray *batch   = [self.versionsBatch copy];
    NSInteger newPendings   = MAX(0, _objectVersionsPending - batch.count);
    
    BOOL shouldHitFinished  = (_indexing && newPendings == 0 && !self.hasPendingVersionRequests);
    
    dispatch_async(bucket.processorQueue, ^{
        if (!self.authenticated) {
            return;
        }
        
        [bucket.indexProcessor processVersions:batch bucket:bucket changeHandler:^(NSString *key) {
            // Local version was different, so nuke old changes, and recalculate the delta
            [bucket.changeProcessor discardPendingChanges:key bucket:bucket];
            [bucket.changeProcessor enqueueObjectForMoreChanges:key bucket:bucket];
        }];
        
        // Now check if indexing is complete
        if (shouldHitFinished) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self allVersionsFinishedForBucket:bucket];
            });
        }
    });
    
    self.objectVersionsPending = newPendings;
    [self.versionsBatch removeAllObjects];
}

- (void)requestVersionsForKeys:(NSArray *)currentIndexArray bucket:(SPBucket *)bucket {
    // Changing entities and saving the context will clear Core Data's updatedObjects. Stash them so
    // sync will still work later for any unsaved changes.
    // In the time between now and when the index refresh completes, any local changes will get marked
    // since regular syncing is disabled during index retrieval.
    [bucket.storage stashUnsavedObjects];

    if ([bucket.delegate respondsToSelector:@selector(bucketWillStartIndexing:)]) {
        [bucket.delegate bucketWillStartIndexing:bucket];
    }

    // Get all the latest versions
    SPLogInfo(@"Simperium processing %lu objects from index (%@)", (unsigned long)[currentIndexArray count], self.name);

    NSArray *indexArrayCopy = [currentIndexArray copy];
    dispatch_async(bucket.processorQueue, ^{
        if (self.authenticated) {
            NSMutableDictionary *pendingVersionRequests = [NSMutableDictionary dictionary];
            
            [bucket.indexProcessor processIndex:indexArrayCopy bucket:bucket versionHandler:^(NSString *key, NSString *version) {
                [pendingVersionRequests setObject:version forKey:key];
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self requestVersionsInBatch:pendingVersionRequests];
            });
            
            // If no requests were queued, then all is good; back to processing
            if (pendingVersionRequests.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self allVersionsFinishedForBucket:bucket];
                });   
            } else {
                SPLogInfo(@"Simperium enqueuing %ld object requests (%@)", (long)pendingVersionRequests.count, bucket.name);
            }
        }
    });
}

- (void)allVersionsFinishedForBucket:(SPBucket *)bucket {
    [self processVersionsBatchForBucket:bucket];

    SPLogInfo(@"Simperium finished processing all objects from index (%@)", self.name);
    
    // Update the Bucket's lastChangeSignature
    bucket.lastChangeSignature      = self.pendingLastChangeSignature;
    
    // All versions were received successfully, so update the lastChangeSignature
    self.pendingLastChangeSignature = nil;
    self.nextMark                   = nil;
    self.indexing                   = NO;

    // There could be some processing happening on the queue still, so don't start until they're done
    dispatch_async(bucket.processorQueue, ^{
        if (!self.authenticated) {
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([bucket.delegate respondsToSelector:@selector(bucketDidFinishIndexing:)]) {
                [bucket.delegate bucketDidFinishIndexing:bucket];
            }

            [self startProcessingChangesForBucket:bucket];
        });
    });
}


#pragma mark ====================================================================================
#pragma mark Sync Timeout
#pragma mark ====================================================================================

- (void)startSyncTimeoutTimer {
    NSAssert([NSThread isMainThread], @"This should get called on the main thread!");
    
    [self.syncTimeoutTimer invalidate];
    self.syncTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:SPWebSocketSyncTimeoutInterval target:self selector:@selector(handleSyncTimeout:) userInfo:nil repeats:NO];
}

- (void)invalidateSyncTimeoutTimer {
    NSAssert([NSThread isMainThread], @"This should get called on the main thread!");
    
    [self.syncTimeoutTimer invalidate];
    self.syncTimeoutTimer = nil;
}

- (void)handleSyncTimeout:(NSTimer *)timer {
    [self.webSocketManager reopen];
}


#pragma mark ====================================================================================
#pragma mark Static Helpers:
#pragma mark MockWebSocketChannel relies on this mechanism to register itself, 
#pragma mark while running the Unit Testing target
#pragma mark ====================================================================================

static Class _class;

+ (void)load {
    _class = [SPWebSocketChannel class];
}

+ (void)registerClass:(Class)c {
    _class = c;
}

+ (instancetype)channelWithSimperium:(Simperium *)s {
    return [[_class alloc] initWithSimperium:s];
}

@end
