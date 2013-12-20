//
//  SPChangeProcessor.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-15.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPChangeProcessor.h"
#import "SPDictionaryStorage.h"
#import "SPManagedObject.h"
#import "NSString+Simperium.h"
#import "SPDiffer.h"
#import "SPBinaryManager.h"
#import "SPStorage.h"
#import "SPMember.h"
#import "JSONKit+Simperium.h"
#import "SPGhost.h"
#import "DDLog.h"
#import "SPBucket.h"
#import "SPDiffer.h"

static int ddLogLevel = LOG_LEVEL_INFO;

NSString * const CH_KEY				= @"id";
NSString * const CH_ADD				= @"+";
NSString * const CH_REMOVE			= @"-";
NSString * const CH_MODIFY			= @"M";
NSString * const CH_OPERATION		= @"o";
NSString * const CH_VALUE			= @"v";
NSString * const CH_START_VERSION   = @"sv";
NSString * const CH_END_VERSION     = @"ev";
NSString * const CH_LOCAL_ID		= @"ccid";
NSString * const CH_ERROR           = @"error";
NSString * const CH_DATA            = @"d";

typedef NS_ENUM(NSUInteger, CH_ERRORS) {
	CH_ERRORS_EXPECTATION_FAILED	= 417,		// (e.g. foreign key doesn't exist just yet)
    CH_ERRORS_INVALID_DIFF			= 440
};


@interface SPChangeProcessor() {
    NSUInteger _inFlightProcessCount;
}
@property (nonatomic, strong, readwrite) NSString				*instanceLabel;
@property (nonatomic, strong, readwrite) SPDictionaryStorage	*changesPending;
@property (nonatomic, strong, readwrite) NSMutableSet			*keysForObjectsWithMoreChanges;
@property (atomic, assign, readwrite, getter = isProcessingChanges) BOOL processingChanges;

-(void)loadKeysForObjectsWithMoreChanges;
@end

@implementation SPChangeProcessor



+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

- (void)increaseInFlightProcess {
    @synchronized(self) {
        if (_inFlightProcessCount == 0) {
            self.processingChanges = YES;
            if (self.isProcessingChangesUpdated) self.isProcessingChangesUpdated(self.processingChanges);
        }
        _inFlightProcessCount++;
    }
}

- (void)decreaseInFlightProcess {
    @synchronized(self) {
        _inFlightProcessCount--;
        if (_inFlightProcessCount == 0) {
            self.processingChanges = NO;
            if (self.isProcessingChangesUpdated) self.isProcessingChangesUpdated(self.processingChanges);
        }
    }
}

- (void)syncInFlightProcess:(dispatch_block_t)block {
    [self increaseInFlightProcess];
    block();
    [self decreaseInFlightProcess];
}

- (void)asyncInFlightProcess:(void (^)(dispatch_block_t processFinished))block {
    [self increaseInFlightProcess];
    void (^finishedBlock)() = ^{ [self decreaseInFlightProcess]; };
    block([finishedBlock copy]);
}

- (id)initWithLabel:(NSString *)label {
    if (self = [super init]) {
        self.instanceLabel = label;
		self.changesPending = [[SPDictionaryStorage alloc] initWithLabel:label];
        self.keysForObjectsWithMoreChanges = [NSMutableSet setWithCapacity:3];
        
        [self loadKeysForObjectsWithMoreChanges];
		[self migratePendingChangesIfNeeded];
    }
    
    return self;
}


- (BOOL)awaitingAcknowledgementForKey:(NSString *)key {
    if (key == nil)
        return NO;
    
    BOOL awaitingAcknowledgement = [self.changesPending objectForKey:key] != nil;
    return awaitingAcknowledgement;
}

// Note: We've moved changesPending collection to SPDictionaryStorage class, which will help to lower memory requirements.
// This method will migrate any pending changes, from UserDefaults over to SPDictionaryStorage
- (void)migratePendingChangesIfNeeded {
    NSString *pendingKey = [NSString stringWithFormat:@"changesPending-%@", self.instanceLabel];
	NSString *pendingJSON = [[NSUserDefaults standardUserDefaults] objectForKey:pendingKey];
	
	// No need to go further
	if(pendingJSON == nil) {
		return;
	}
	
	// Proceed migrating!
    DDLogInfo(@"Migrating changesPending collection to SPDictionaryStorage");
    
    NSDictionary *pendingDict = [pendingJSON sp_objectFromJSONString];

	for(NSString *key in pendingDict.allKeys) {
		id change = pendingDict[key];
		if(change) {
			[self.changesPending setObject:change forKey:key];
		}
	}
	
	[self.changesPending save];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:pendingKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)serializeKeysForObjectsWithMoreChanges {
    NSString *json = [[self.keysForObjectsWithMoreChanges allObjects] sp_JSONString];
    NSString *key = [NSString stringWithFormat:@"keysForObjectsWithMoreChanges-%@", self.instanceLabel];
	[[NSUserDefaults standardUserDefaults] setObject:json forKey: key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadKeysForObjectsWithMoreChanges {
    // Load keys for entities that have more changes to send
    NSString *key = [NSString stringWithFormat:@"keysForObjectsWithMoreChanges-%@", self.instanceLabel];
	NSString *json = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    NSArray *list = [json sp_objectFromJSONString];
    if (list && [list count] > 0) {
        [self.keysForObjectsWithMoreChanges addObjectsFromArray:list];
	}
}

- (void)reset {
    [self.changesPending removeAllObjects];
	[self.changesPending save];
    [self.keysForObjectsWithMoreChanges removeAllObjects];
    [self serializeKeysForObjectsWithMoreChanges];
}

// For debugging
- (void)softReset {
    [self.changesPending removeAllObjects];
    [self.keysForObjectsWithMoreChanges removeAllObjects];
    [self loadKeysForObjectsWithMoreChanges];
}


#pragma mark Remote changes

- (BOOL)change:(NSDictionary *)change equals:(NSDictionary *)anotherChange {
	return [[change objectForKey:CH_KEY] compare:[anotherChange objectForKey:CH_KEY]] == NSOrderedSame &&
    [[change objectForKey:CH_LOCAL_ID] compare:[anotherChange objectForKey:CH_LOCAL_ID]] == NSOrderedSame;
}

- (BOOL)processRemoteResponseForChanges:(NSArray *)changes bucket:(SPBucket *)bucket {

    __block BOOL repostNeeded = NO;

    [self syncInFlightProcess:^{
        for (NSDictionary *change in changes) {
            if (change[CH_ERROR] != nil) {
                long errorCode = [change[CH_ERROR] integerValue];
                DDLogError(@"Simperium POST returned error %ld for change %@", errorCode, change);

                if (errorCode == CH_ERRORS_EXPECTATION_FAILED || errorCode == CH_ERRORS_INVALID_DIFF) {
                    // Resubmit with all data
                    // Create a new context (to be thread-safe) and fetch the entity from it
                    id<SPStorageProvider>threadSafeStorage = [bucket.storage threadSafeStorage];
                    [threadSafeStorage beginSafeSection];

                    NSString *key = change[CH_KEY];
                    id<SPDiffable>object = [threadSafeStorage objectForKey:key bucketName :bucket.name];

                    if (!object) {
                        [self.changesPending removeObjectForKey:change[CH_KEY]];
                        [threadSafeStorage finishSafeSection];
                        continue;
                    }
                    NSMutableDictionary *newChange = [[self.changesPending objectForKey:key] mutableCopy];

                    [object simperiumKey]; // fire fault
                    [newChange setObject:[object dictionary] forKey:CH_DATA];
                    [self.changesPending setObject:newChange forKey:key];
                    repostNeeded = YES;

                    [threadSafeStorage finishSafeSection];
                } else {
                    // Catch all, don't resubmit
                    [self.changesPending removeObjectForKey:change[CH_KEY]];
                }
            }
        }
        [self.changesPending save];
    }];

    return repostNeeded;
}

- (BOOL)processRemoteDeleteWithKey:(NSString*)simperiumKey bucket:(SPBucket *)bucket acknowledged:(BOOL)acknowledged {
	
	// REMOVE operation
	// If this wasn't just an ack, perform the deletion
	if (!acknowledged) {
		DDLogVerbose(@"Simperium non-local REMOVE ENTITY received");
		
		id<SPStorageProvider> threadSafeStorage = [bucket.storage threadSafeStorage];
		[threadSafeStorage beginCriticalSection];
		
		id<SPDiffable> object = [threadSafeStorage objectForKey:simperiumKey bucketName:bucket.name];
		
		if(object) {
			[threadSafeStorage deleteObject:object];
			[threadSafeStorage save];
		}

		[threadSafeStorage finishCriticalSection];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			NSDictionary *userInfo = @{
										@"bucketName"	: bucket.name,
										@"keys"			: [NSSet setWithObject:simperiumKey]
									 };
			[[NSNotificationCenter defaultCenter] postNotificationName:ProcessorDidDeleteObjectKeysNotification object:bucket userInfo:userInfo];
		});

	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			// Not really useful except for testing
			NSDictionary *userInfo = @{  @"bucketName" : bucket.name };
			[[NSNotificationCenter defaultCenter] postNotificationName:ProcessorDidAcknowledgeDeleteNotification object:bucket userInfo:userInfo];
		});
	}
	
    return YES;
}

- (BOOL)processRemoteModifyWithKey:(NSString *)simperiumKey bucket:(SPBucket *)bucket change:(NSDictionary *)change acknowledged:(BOOL)acknowledged
{
    id<SPStorageProvider>threadSafeStorage = [bucket.storage threadSafeStorage];
	[threadSafeStorage beginSafeSection];
	
    id<SPDiffable> object = [threadSafeStorage objectForKey:simperiumKey bucketName:bucket.name];
	
    BOOL newlyAdded = NO;
    NSString *key = [change objectForKey:CH_KEY];
    
    // MODIFY operation
    if (!object) {
        newlyAdded = YES;
        // It doesn't exist yet, so ADD it
        
        // Create the new object
        object = [threadSafeStorage insertNewObjectForBucketName:bucket.name simperiumKey:key];
        DDLogVerbose(@"Simperium managing newly added entity %@", [object simperiumKey]);
        
        // Remember this object's ghost for future diffing			
        // Send nil member data because it'll get loaded below
        SPGhost *ghost = [[SPGhost alloc] initWithKey:[object simperiumKey] memberData:nil];
        ghost.version = @"0";
        object.ghost = ghost;
        
        // If this wasn't just an ack, send a notification and load the data
        DDLogVerbose(@"Simperium non-local ADD ENTITY received");
    }
    
    // Another hack since 'ghost' isn't transient: check for fault and forcefire if necessary
    [object willBeRead];
    
    // It already exists, now MODIFY it
    if (!object.ghost) {
        DDLogWarn(@"Simperium warning: received change for unknown entity (%@): %@", bucket.name, key);
		[threadSafeStorage finishSafeSection];
        return NO;
    }
    
    // Make sure the expected last change matches the actual last change
    NSString *oldVersion = [object.ghost version];
    id startVersion = [change objectForKey:CH_START_VERSION];
    id endVersion = [change objectForKey:CH_END_VERSION];
    
    // Store versions as strings, but if they come off the wire as numbers, then handle that too
    if ([startVersion isKindOfClass:[NSNumber class]])
        startVersion = [NSString stringWithFormat:@"%ld", (long)[startVersion integerValue]];
    if ([endVersion isKindOfClass:[NSNumber class]])
        endVersion = [NSString stringWithFormat:@"%ld", (long)[endVersion integerValue]];
    
    DDLogVerbose(@"Simperium received version = %@, previous version = %@", startVersion, oldVersion);
    // If the versions are equal or there's no start version (new object), process the change
    if (startVersion == nil || [oldVersion isEqualToString:startVersion]) {
        // Remember the old ghost
        SPGhost *oldGhost = [object.ghost copy];
        NSDictionary *remoteDiff = [change objectForKey:CH_VALUE];
        
        // Apply the diff to the ghost and store the new data in the object's ghost
        [bucket.differ applyGhostDiff: remoteDiff to:object];
        object.ghost.version = endVersion;
        
        // Slight hack to ensure Core Data realizes the object has changed and needs a save
        NSString *ghostDataCopy = [[[object.ghost dictionary] sp_JSONString] copy];
        object.ghostData = ghostDataCopy;
        
        DDLogVerbose(@"Simperium MODIFIED ghost version %@ (%@-%@)", endVersion, bucket.name, self.instanceLabel);
        
        // If it wasn't an ack, then local data needs to be updated and the app needs to be notified
        if (!acknowledged && !newlyAdded) {
            DDLogVerbose(@"Simperium non-local MODIFY ENTITY received");
            NSDictionary *localDiff = [bucket.differ diff:object fromDictionary:[oldGhost memberData]];
            if ([localDiff count] > 0 && oldGhost.memberData.count) {
                // The local client version changed in the meantime, so transform the diff before applying it
                DDLogVerbose(@"Simperium applying transform to diff: %@", remoteDiff);			
                NSDictionary *transformedRemoteDiff = [bucket.differ transform:object diff:localDiff oldDiff:remoteDiff oldGhost: oldGhost];
                
                // Load from the ghost data so the subsequent diff is applied to the correct data
                // Do an extra check in case there was a problem with the transform/diff, e.g. if a client's own change was misinterpreted
                // as another client's change, in other words not properly acknowledged.
                if ([transformedRemoteDiff count] > 0) {
                    [object loadMemberData: [object.ghost memberData]];
                    remoteDiff = transformedRemoteDiff;
                }
            }
        }
        
        // Apply the diff to the object itself
        if (!acknowledged && [remoteDiff count] > 0) {
            DDLogVerbose(@"Simperium applying diff: %@", remoteDiff);
            [bucket.differ applyDiff: remoteDiff to:object];
        }
        [threadSafeStorage save];
		
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                      bucket.name, @"bucketName",
                                      [NSSet setWithObject:key], @"keys", nil];
            NSString *notificationName;
            if (newlyAdded) {
                notificationName = ProcessorDidAddObjectsNotification;
            } else if (acknowledged) {
                notificationName = ProcessorDidAcknowledgeObjectsNotification;
            } else {
                notificationName = ProcessorDidChangeObjectNotification;                
                [userInfo setObject:[remoteDiff allKeys] forKey:@"changedMembers"];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:bucket userInfo:userInfo];
        });
        
    } else {
        DDLogWarn(@"Simperium warning: couldn't apply change due to version mismatch (duplicate? start %@, old %@): change %@", startVersion, oldVersion, change);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:ProcessorRequestsReindexing object:bucket];
        });
    }
	
	[threadSafeStorage finishSafeSection];
	
    return YES;
}

- (BOOL)processRemoteChange:(NSDictionary *)change bucket:(SPBucket *)bucket clientID:(NSString *)clientID {
    // Create a new context (to be thread-safe) and fetch the entity from it
    id<SPStorageProvider>threadSafeStorage = [bucket.storage threadSafeStorage];
	[threadSafeStorage beginSafeSection];
	
    NSString *operation = [change objectForKey:CH_OPERATION];
    NSString *changeVersion = [change objectForKey:@"cv"];
    NSString *changeClientID = [change objectForKey:@"clientid"];
    NSString *key = [change objectForKey:CH_KEY];
    id<SPDiffable> object = [threadSafeStorage objectForKey:key bucketName:bucket.name];
    
    DDLogVerbose(@"Simperium client %@ received change (%@) %@: %@", clientID, bucket.name, changeClientID, change);
    
	// Check for an error
    if ([change objectForKey:CH_ERROR]) {
        DDLogVerbose(@"Simperium error received (%@) for %@, should reload the object here to be safe", bucket.name, key);
        [self.changesPending removeObjectForKey:key];
		[threadSafeStorage finishSafeSection];
        return NO;
    }
	
	// Process
    BOOL clientMatches = [changeClientID compare:clientID] == NSOrderedSame;
    BOOL remove = operation && [operation compare: CH_REMOVE] == NSOrderedSame;
    BOOL acknowledged = [self awaitingAcknowledgementForKey:key] && clientMatches;
    
    // If the entity already exists locally, or it's being removed, then check for an ack
    if (remove || (object && acknowledged && clientMatches)) {
        // TODO: If this isn't a deletion change, but there's a deletion change pending, then ignore this change
        // Change was awaiting acknowledgement; safe now to remove from changesPending
        if (acknowledged) {
            DDLogVerbose(@"Simperium acknowledged change for %@, cv=%@", changeClientID, changeVersion);
		}
        [self.changesPending removeObjectForKey:key];
    }

    DDLogVerbose(@"Simperium performing change operation: %@", operation);
	[threadSafeStorage finishSafeSection];
		
    if (remove) {
        if (object || acknowledged) {
            return [self processRemoteDeleteWithKey:key bucket:bucket acknowledged:acknowledged];
		}
    } else if (operation && [operation compare: CH_MODIFY] == NSOrderedSame) {
        return [self processRemoteModifyWithKey:key bucket:bucket change:change acknowledged:acknowledged];
    }
	
	// invalid
	DDLogError(@"Simperium error (%@), received an invalid change for (%@): %@", bucket.name, key, change);
    return NO;
}

- (void)processRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket clientID:(NSString *)clientID {

    [self asyncInFlightProcess:^(dispatch_block_t processFinished) {
        NSMutableSet *changedKeys = [NSMutableSet setWithCapacity:[changes count]];

        // Construct a list of keys for a willChange notification (and ignore acks)
        for (NSDictionary *change in changes) {
            NSString *key = change[CH_KEY];
            if (![self awaitingAcknowledgementForKey:key]) {
                [changedKeys addObject:key];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{

            if (changedKeys.count > 0) {
                NSDictionary *userInfo = @{
                                           @"bucketName"	: bucket.name,
                                           @"keys"			: changedKeys
                                           };

                [[NSNotificationCenter defaultCenter] postNotificationName:ProcessorWillChangeObjectsNotification object:bucket userInfo:userInfo];
            }

            // The above notification needs to give the main thread a chance to react before we continue
            dispatch_async(bucket.processorQueue, ^{
                for (NSDictionary *change in changes) {
                    // Process the change (this is necessary even if it's an ack, so the ghost data gets set accordingly)
                    if (![self processRemoteChange:change bucket:bucket clientID:clientID]) {
                        continue;
                    }

                    // Remember the last version
                    // This persists...do it inside the loop in case something happens to abort the loop
                    NSString *changeVersion = change[@"cv"];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [bucket setLastChangeSignature: changeVersion];
                    });        
                }
                
                [self.changesPending save];
                
                if(self.changesPending.count == 0) {
                    [bucket bucketDidSync];
                }
                processFinished();
            });
        });
    }];
}


#pragma mark Local changes

- (NSMutableDictionary *)createChangeForKey:(NSString *)key operation:(NSString *)operation version:(NSString *)version data:(NSDictionary *)data {
	// The change applies to this particular entity instance, so use its unique key as an identifier
	NSMutableDictionary *change = [NSMutableDictionary dictionaryWithObject:key forKey:CH_KEY];
	
	// Every change must be marked with a unique ID
	NSString *uuid = [NSString sp_makeUUID];
	[change setObject:uuid forKey: CH_LOCAL_ID];
	
	// Set the change's operation
	[change setObject:operation forKey:CH_OPERATION];
    
	// Set the data as the value for the operation (e.g. a diff dictionary for modify operations)
    if (data)
        [change setObject:data forKey:CH_VALUE];
	
	// If it's a modify operation, also include the object's version as the last known version
	if (operation == CH_MODIFY && version != nil && [version intValue] != 0)
        [change setObject: version forKey: CH_START_VERSION];
	
	return change;
}

- (void)processLocalChange:(NSDictionary *)change key:(NSString *)key {
    [self syncInFlightProcess:^{
        [self.changesPending setObject:change forKey:key];
        [self.changesPending save];
    }];
}

- (NSDictionary *)processLocalDeletionWithKey:(NSString *)key {
    __block NSDictionary *change = nil;
    [self syncInFlightProcess:^{
        change = [self createChangeForKey:key operation:CH_REMOVE version:nil data:nil];
    }];
    return change;
}

- (NSDictionary *)processLocalObjectWithKey:(NSString *)key bucket:(SPBucket *)bucket later:(BOOL)later {
    __block NSDictionary *change = nil;
    [self syncInFlightProcess:^{

        // Create a new context (to be thread-safe) and fetch the entity from it
        id<SPStorageProvider> storage = [bucket.storage threadSafeStorage];
        [storage beginSafeSection];

        id<SPDiffable> object = [storage objectForKey:key bucketName:bucket.name];

        // If the object no longer exists, it was likely previously deleted, in which case this change is no longer
        // relevant
        if (!object) {
            //DDLogWarn(@"Simperium warning: couldn't processLocalObjectWithKey %@ because the object no longer exists", key);
            [self.changesPending removeObjectForKey:key];
            [self.keysForObjectsWithMoreChanges removeObject:key];
            [self.changesPending save];
            [self serializeKeysForObjectsWithMoreChanges];
            [storage finishSafeSection];
            return;
        }

        // If there are already changes pending for this entity, mark this entity and come back to it later to get the changes
        if (([self.changesPending objectForKey:object.simperiumKey] != nil) || later) {
            DDLogVerbose(@"Simperium marking object for sending more changes when ready (%@): %@", bucket.name, object.simperiumKey);
            [self.keysForObjectsWithMoreChanges addObject:[object simperiumKey]];
            [self serializeKeysForObjectsWithMoreChanges];
            [storage finishSafeSection];
            return;
        }

        NSDictionary *newData;
        DDLogVerbose(@"Simperium processing local object changes (%@): %@", bucket.name, object.simperiumKey);

        if (object.ghost != nil && [object.ghost memberData] != nil) {
            // This object has already been synced in the past and has a server ghost, so we're
            // modifying the object

            // Get a diff of the object (in dictionary form)
            newData = [bucket.differ diff:object fromDictionary: [object.ghost memberData]];
            DDLogVerbose(@"Simperium entity diff found %lu changed members", (unsigned long)[newData count]);
            if ([newData count] > 0) {
                change = [self createChangeForKey: object.simperiumKey operation: CH_MODIFY version:object.ghost.version data: newData];
            } else {
                // No difference, don't do anything else
                DDLogVerbose(@"Simperium warning: no difference in call to sendChanges (%@): %@", bucket.name, object.simperiumKey);
                [storage finishSafeSection];
                return;
            }

        } else /*if (!entity.deleted)*/ {
            DDLogVerbose(@"Simperium local ADD detected, creating diff...");

            newData = [bucket.differ diffForAddition:object];
            change = [self createChangeForKey: object.simperiumKey operation:CH_MODIFY version: object.ghost.version data: newData];
        }
        
        [storage finishSafeSection];

    }];

    return change;
}

- (void)enumeratePendingChanges:(SPBucket *)bucket onlyQueuedChanges:(BOOL)onlyQueuedChanges block:(void (^)(NSDictionary *change))block {

    if (self.keysForObjectsWithMoreChanges.count == 0 && (onlyQueuedChanges || self.changesPending.count == 0)) {
		return;
	}
    [self syncInFlightProcess:^{
        DDLogVerbose(@"Simperium found %lu objects with more changes to send (%@)", (unsigned long)self.keysForObjectsWithMoreChanges.count, bucket.name);

        NSMutableSet *queuedKeys = [NSMutableSet setWithCapacity:self.keysForObjectsWithMoreChanges.count];
        NSMutableSet *pendingKeys = [NSMutableSet setWithArray:self.changesPending.allKeys];

        // Create a list of the keys to be processed
        for (NSString *key in self.keysForObjectsWithMoreChanges) {
            // If there are already changes pending, don't add any more
            // Importantly, this prevents a potential mutation of keysForObjectsWithMoreChanges in processLocalObjectWithKey:later:
            if ([pendingKeys containsObject:key] == NO) {
                [queuedKeys addObject:key];
            }
        }

        // Create changes for any objects that have more changes
        for(NSString* key in queuedKeys) {
            NSDictionary *change = [self processLocalObjectWithKey:key bucket:bucket later:NO];

            if (change) {
                [self.changesPending setObject:change forKey:key];
                [pendingKeys addObject:key];
            } else {
                [self.keysForObjectsWithMoreChanges removeObject:key];
            }
        }

        // Enumerate:
        //	pendingKeys: Queued + previously pending
        //	queuedKeys: Only queued objects
        NSSet *changesPendingKeys = (onlyQueuedChanges ? queuedKeys : pendingKeys);

        for(NSString *key in changesPendingKeys) {
            NSDictionary* change = [self.changesPending objectForKey:key];
            if(change) {
                block(change);
            }
        }
        
        // Clear any keys that were processed into pending changes & Persist
        [self.changesPending save];
        [self.keysForObjectsWithMoreChanges minusSet:queuedKeys];
        [self serializeKeysForObjectsWithMoreChanges];

    }];
}

- (NSArray *)processKeysForObjectsWithMoreChanges:(SPBucket *)bucket {
    // Check if there are more changes that need to be sent
    NSMutableArray *newChangesPending = [NSMutableArray arrayWithCapacity:3];

    [self syncInFlightProcess:^{
        if ([self.keysForObjectsWithMoreChanges count] > 0) {
            DDLogVerbose(@"Simperium found %lu objects with more changes to send (%@)", (unsigned long)[self.keysForObjectsWithMoreChanges count], bucket.name);

            NSMutableSet *keysProcessed = [NSMutableSet setWithCapacity:self.keysForObjectsWithMoreChanges.count];
            // Create changes for any objects that have more changes
            for (NSString *key in self.keysForObjectsWithMoreChanges) {
                // If there are already changes pending, don't add any more
                // Importantly, this prevents a potential mutation of keysForObjectsWithMoreChanges in processLocalObjectWithKey:later:
                if ([self.changesPending objectForKey: key] != nil)
                    continue;

                NSDictionary *change = [self processLocalObjectWithKey:key bucket:bucket later:NO];

                if (change) {
                    [self.changesPending setObject:change forKey:key];
                    [newChangesPending addObject:change];
                }
                [keysProcessed addObject:key];
            }

            // Clear any keys that were processed into pending changes
            [self.keysForObjectsWithMoreChanges minusSet:keysProcessed];

            // Persist pending changes
            [self.changesPending save];
        }
        
        [self serializeKeysForObjectsWithMoreChanges];
    }];
    // TODO: to fix duplicate send, make this return only changes for keysProcessed?
    return newChangesPending;
}


- (int)numChangesPending {
    return (int)[self.changesPending count];
}

- (int)numKeysForObjectsWithMoreChanges {
    return (int)[self.keysForObjectsWithMoreChanges count];
}

- (NSArray*)exportPendingChanges {
	
	// This routine shall be used for debugging purposes!
	NSMutableArray* pendings = [NSMutableArray array];
	for(NSDictionary* change in self.changesPending.allValues) {
				
		NSMutableDictionary* export = [NSMutableDictionary dictionary];
		
		[export setObject:[change[CH_KEY] copy] forKey:CH_KEY];				// Entity Id
		[export setObject:[change[CH_LOCAL_ID] copy] forKey:CH_LOCAL_ID];	// Change Id: ccid
		
		// Start Version is not available for newly inserted objects
		NSString* startVersion = change[CH_START_VERSION];
		if(startVersion) {
			[export setObject:[startVersion copy] forKey:CH_START_VERSION];
		}
		
		[pendings addObject:export];
	}
	
	return pendings;
}

@end
