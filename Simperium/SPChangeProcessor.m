//
//  SPChangeProcessor.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-15.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPChangeProcessor.h"
#import "SPManagedObject.h"
#import "NSString+Simperium.h"
#import "SPDiffer.h"
#import "SPBinaryManager.h"
#import "SPStorage.h"
#import "SPMember.h"
#import "JSONKit.h"
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

// Notifications
NSString * const ProcessorDidAddObjectsNotification = @"ProcessorDidAddObjectsNotification";
NSString * const ProcessorDidChangeObjectsNotification = @"ProcessorDidChangeObjectsNotification";
NSString * const ProcessorDidDeleteObjectKeysNotification = @"ProcessorDidDeleteObjectKeysNotification";
NSString * const ProcessorDidAcknowledgeObjectsNotification = @"ProcessorDidAcknowledgeObjectsNotification";
NSString * const ProcessorWillChangeObjectsNotification = @"ProcessorWillChangeObjectsNotification";
NSString * const ProcessorDidAcknowledgeDeleteNotification = @"ProcessorDidAcknowledgeDeleteNotification";

@interface SPChangeProcessor()
-(void)loadSerializedChanges;
-(void)loadKeysForObjectsWithMoreChanges;
@end

@implementation SPChangeProcessor
@synthesize instanceLabel;

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

-(id)initWithLabel:(NSString *)label {
    if (self = [super init]) {
        self.instanceLabel = label;
		changesPending = [[NSMutableDictionary dictionaryWithCapacity:3] retain];
        keysForObjectsWithMoreChanges = [[NSMutableSet setWithCapacity:3] retain];
        
        [self loadSerializedChanges];
        [self loadKeysForObjectsWithMoreChanges];
    }
    
    return self;
}

-(void)dealloc {
    self.instanceLabel = nil;
    [changesPending release];
    [keysForObjectsWithMoreChanges release];
    [super dealloc];
}

-(NSMutableDictionary *)createChangeForKey:(NSString *)key operation:(NSString *)operation version:(NSString *)version data:(NSDictionary *)data
{
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

-(BOOL)awaitingAcknowledgementForKey:(NSString *)key {
    if (key == nil)
        return NO;
    
    BOOL awaitingAcknowledgement = [changesPending objectForKey:key] != nil;
    return awaitingAcknowledgement;
}

-(void)serializeChangesPending
{
    NSString *pendingJSON = [changesPending JSONString];
    NSString *key = [NSString stringWithFormat:@"changesPending-%@", instanceLabel];
	[[NSUserDefaults standardUserDefaults] setObject:pendingJSON forKey: key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)serializeKeysForObjectsWithMoreChanges
{
    NSString *json = [[keysForObjectsWithMoreChanges allObjects] JSONString];
    NSString *key = [NSString stringWithFormat:@"keysForObjectsWithMoreChanges-%@", instanceLabel];
	[[NSUserDefaults standardUserDefaults] setObject:json forKey: key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)loadSerializedChanges
{    
    // Load changes that didn't get a chance to send
    NSString *pendingKey = [NSString stringWithFormat:@"changesPending-%@", instanceLabel];
	NSString *pendingJSON = [[NSUserDefaults standardUserDefaults] objectForKey:pendingKey];
    NSDictionary *pendingDict = [pendingJSON objectFromJSONString];
    if (pendingDict && [pendingDict count] > 0)
        [changesPending setValuesForKeysWithDictionary:pendingDict];
}

-(void)loadKeysForObjectsWithMoreChanges
{    
    // Load keys for entities that have more changes to send
    NSString *key = [NSString stringWithFormat:@"keysForObjectsWithMoreChanges-%@", instanceLabel];
	NSString *json = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    NSArray *list = [json objectFromJSONString];
    if (list && [list count] > 0)
        [keysForObjectsWithMoreChanges addObjectsFromArray:list];
}

-(void)reset
{
    [changesPending removeAllObjects];
    [keysForObjectsWithMoreChanges removeAllObjects];
    [self serializeChangesPending];
    [self serializeKeysForObjectsWithMoreChanges];
}

// For debugging
-(void)softReset
{
    [changesPending removeAllObjects];
    [keysForObjectsWithMoreChanges removeAllObjects];
    [self loadSerializedChanges];
    [self loadKeysForObjectsWithMoreChanges];
}

-(BOOL)processRemoteResponseForChanges:(NSArray *)changes bucket:(SPBucket *)bucket
{
    BOOL repostNeeded = NO;
    for (NSDictionary *change in changes) {
        if ([change objectForKey:CH_ERROR] != nil) {
            int errorCode = [[change objectForKey:CH_ERROR] integerValue];
            DDLogError(@"Simperium POST returned error %d for change %@", errorCode, change);
            
            // 440: invalid diff
            // 417: expectation failed (e.g. foreign key doesn't exist just yet)
            if (errorCode == 440 || errorCode == 417) {
                // Resubmit with all data
                // Create a new context (to be thread-safe) and fetch the entity from it
                NSString *key = [change objectForKey:CH_KEY];
                id<SPStorageProvider>threadSafeStorage = [bucket.storage threadSafeStorage];
                id<SPDiffable>object = [threadSafeStorage objectForKey:key bucketName :bucket.name];
                
                if (!object) {
                    [changesPending removeObjectForKey:[change objectForKey:CH_KEY]];
                    continue;
                }
                NSMutableDictionary *newChange = [[changesPending objectForKey:key] mutableCopy];
                [object simperiumKey]; // fire fault
                [newChange setObject:[object dictionary] forKey:CH_DATA];
                [changesPending setObject:newChange forKey:key];
                [newChange release];
                repostNeeded = YES;
            } else {
                // Catch all, don't resubmit
                [changesPending removeObjectForKey:[change objectForKey:CH_KEY]];
            }
        }
    }
    
    return repostNeeded;
}

-(BOOL)change:(NSDictionary *)change equals:(NSDictionary *)anotherChange
{
	return [[change objectForKey:CH_KEY] compare:[anotherChange objectForKey:CH_KEY]] == NSOrderedSame &&
    [[change objectForKey:CH_LOCAL_ID] compare:[anotherChange objectForKey:CH_LOCAL_ID]] == NSOrderedSame;
}

-(BOOL)processRemoteDelete:(id<SPDiffable>)object acknowledged:(BOOL)acknowledged bucket:(SPBucket *)bucket storage:(id<SPStorageProvider>)threadSafeStorage
{
    // REMOVE operation
    // If this wasn't just an ack, perform the deletion
    NSString *key = [object simperiumKey];

    if (!acknowledged) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  bucket.name, @"bucketName",
                                  [NSSet setWithObject:key], @"keys", nil];

        DDLogVerbose(@"Simperium non-local REMOVE ENTITY received");
        [threadSafeStorage deleteObject: object];
        [threadSafeStorage save];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:ProcessorDidDeleteObjectKeysNotification object:bucket userInfo:userInfo];
        });

    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Not really useful except for testing
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys: bucket.name, @"bucketName", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:ProcessorDidAcknowledgeDeleteNotification object:bucket userInfo:userInfo];
        });
    }
    return YES;
}

-(BOOL)processRemoteModify:(id<SPDiffable>)object bucket:(SPBucket *)bucket change:(NSDictionary *)change acknowledged:(BOOL)acknowledged storage:(id<SPStorageProvider>)threadSafeStorage
{
    BOOL newlyAdded = NO;
    NSString *key = [change objectForKey:CH_KEY];
    
    // MODIFY operation
    if (!object)
    {
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
        [ghost release];
        
        // If this wasn't just an ack, send a notification and load the data
        DDLogVerbose(@"Simperium non-local ADD ENTITY received");
    }
    
    // Another hack since 'ghost' isn't transient: check for fault and forcefire if necessary
    [object willBeRead];
    
    // It already exists, now MODIFY it
    if (!object.ghost) {
        DDLogWarn(@"Simperium warning: received change for unknown entity (%@): %@", bucket.name, key);
        return NO;
    }
    
    // Make sure the expected last change matches the actual last change
    NSString *oldVersion = [object.ghost version];
    id startVersion = [change objectForKey:CH_START_VERSION];
    id endVersion = [change objectForKey:CH_END_VERSION];
    
    // Store versions as strings, but if they come off the wire as numbers, then handle that too
    if ([startVersion isKindOfClass:[NSNumber class]])
        startVersion = [NSString stringWithFormat:@"%d", [startVersion integerValue]];
    if ([endVersion isKindOfClass:[NSNumber class]])
        endVersion = [NSString stringWithFormat:@"%d", [endVersion integerValue]];
    
    DDLogVerbose(@"Simperium received version = %@, previous version = %@", startVersion, oldVersion);
    // If the versions are equal or there's no start version (new object), process the change
    if (startVersion == nil || [oldVersion isEqualToString:startVersion]) {
        // Remember the old ghost
        SPGhost *oldGhost = [object.ghost copy];
        NSDictionary *diff = [change objectForKey:CH_VALUE];
        
        // Apply the diff to the ghost and store the new data in the object's ghost
        [bucket.differ applyGhostDiff: diff to:object];
        object.ghost.version = endVersion;
        
        // Slight hack to ensure Core Data realizes the object has changed and needs a save
        NSString *ghostDataCopy = [[[object.ghost dictionary] JSONString] copy];
        object.ghostData = ghostDataCopy;
        [ghostDataCopy release];
        
        DDLogVerbose(@"Simperium MODIFIED ghost version %@ (%@-%@)", endVersion, bucket.name, instanceLabel);
        
        // If it wasn't an ack, then local data needs to be updated and the app needs to be notified
        if (!acknowledged && !newlyAdded) {
            DDLogVerbose(@"Simperium non-local MODIFY ENTITY received");
            NSDictionary *oldDiff = [bucket.differ diff:object withDictionary:[oldGhost memberData]];
            if ([oldDiff count] > 0) {
                // The local client version changed in the meantime, so transform the diff before applying it
                DDLogVerbose(@"Simperium applying transform to diff: %@", diff);			
                diff = [bucket.differ transform:object diff:oldDiff oldDiff: diff oldGhost: oldGhost];
                
                // Load from the ghost data so the subsequent diff is applied to the correct data
                // Do an extra check in case there was a problem with the transform/diff, e.g. if a client's own change was misinterpreted
                // as another client's change, in other words not properly acknowledged.
                if ([diff count] > 0)
                    [object loadMemberData: [object.ghost memberData]];
                else
                    DDLogVerbose(@"Simperium transform resulted in empty diff (invalid ack?)");
            }
        }
        [oldGhost release];
        
        // Apply the diff to the object itself
        if (!acknowledged && [diff count] > 0) {
            DDLogVerbose(@"Simperium applying diff: %@", diff);
            [bucket.differ applyDiff: diff to:object];
        }
        [threadSafeStorage save];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      bucket.name, @"bucketName",
                                      [NSSet setWithObject:key], @"keys", nil];
            NSString *notificationName;
            if (newlyAdded) {
                notificationName = ProcessorDidAddObjectsNotification;
            } else if (acknowledged)
                notificationName = ProcessorDidAcknowledgeObjectsNotification;
            else
                notificationName = ProcessorDidChangeObjectsNotification;
            [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:bucket userInfo:userInfo];
        });
        
    } else {
        DDLogWarn(@"Simperium warning: couldn't apply change due to version mismatch (duplicate? start %@, old %@): change %@", startVersion, oldVersion, change);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"simperiumIndexRefreshNeeded" object:bucket];
        });
    }
    
    return YES;
}

-(BOOL)processRemoteChange:(NSDictionary *)change bucket:(SPBucket *)bucket clientID:(NSString *)clientID
{
    // Create a new context (to be thread-safe) and fetch the entity from it
    id<SPStorageProvider>threadSafeStorage = [bucket.storage threadSafeStorage];

    NSString *operation = [change objectForKey:CH_OPERATION];
    NSString *changeVersion = [change objectForKey:@"cv"];
    NSString *changeClientID = [change objectForKey:@"clientid"];
    NSString *key = [change objectForKey:CH_KEY];
    id<SPDiffable> object = [threadSafeStorage objectForKey:key bucketName:bucket.name];
    
    DDLogVerbose(@"Simperium client %@ received change (%@) %@: %@", clientID, bucket.name, changeClientID, change);
    
    BOOL clientMatches = [changeClientID compare:clientID] == NSOrderedSame;
    BOOL remove = [operation compare: CH_REMOVE] == NSOrderedSame;
    BOOL acknowledged = [self awaitingAcknowledgementForKey:key] && clientMatches;
    
    // If the entity already exists locally, or it's being removed, then check for an ack
    if (remove || (object && acknowledged && clientMatches)) {
        // TODO: If this isn't a deletion change, but there's a deletion change pending, then ignore this change
        // Change was awaiting acknowledgement; safe now to remove from changesPending
        if (acknowledged)
            DDLogVerbose(@"Simperium acknowledged change for %@, cv=%@", changeClientID, changeVersion);
        [changesPending removeObjectForKey:key];
    }
    
    // Check for an error
    if ([change objectForKey:CH_ERROR]) {
        DDLogVerbose(@"Simperium error received (%@) for %@, should reload the object here to be safe", bucket.name, key);
        [changesPending removeObjectForKey:key];
        return NO;
    }
    
    DDLogVerbose(@"Simperium performing change operation: %@", operation);
    
    if (remove)
    {
        if (object || acknowledged)
            return [self processRemoteDelete: object acknowledged:acknowledged bucket:bucket storage:threadSafeStorage];
    } else if ([operation compare: CH_MODIFY] == NSOrderedSame) {
        return [self processRemoteModify: object bucket:bucket change: change acknowledged:acknowledged storage:threadSafeStorage];
    }
    
    // invalid
    DDLogError(@"Simperium error (%@), received an invalid change for (%@)", bucket.name, key);
    return NO;
}

-(void)processRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket clientID:(NSString *)clientID
{
    NSMutableSet *changedKeys = [NSMutableSet setWithCapacity:[changes count]];
    for (NSDictionary *change in changes) {
        NSString *key = [change objectForKey:CH_KEY];
        [changedKeys addObject:key];
    }

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              bucket.name, @"bucketName",
                              changedKeys, @"keys", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:ProcessorWillChangeObjectsNotification object:bucket userInfo:userInfo];

    for (NSDictionary *change in changes) {
        // Process the change (this is necessary even if it's an ack, so the ghost data gets set accordingly)
        if (![self processRemoteChange:change bucket:bucket clientID:clientID]) {
            continue;
        }
        
        // Remember the last version
        // This persists...do it inside the loop in case something happens to abort the loop        
        NSString *changeVersion = [change objectForKey:@"cv"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [bucket setLastChangeSignature: changeVersion];
        });        
    }
    
    [self serializeChangesPending];        
}

-(void)processLocalChange:(NSDictionary *)change key:(NSString *)key
{
    [changesPending setObject:change forKey: key];
    [self serializeChangesPending];
}

-(NSDictionary *)processLocalDeletionWithKey:(NSString *)key
{
    NSDictionary *change = [self createChangeForKey:key operation:CH_REMOVE version:nil data:nil];
    return change;
}

-(NSDictionary *)processLocalObjectWithKey:(NSString *)key bucket:(SPBucket *)bucket later:(BOOL)later
{
    // Create a new context (to be thread-safe) and fetch the entity from it
    id<SPStorageProvider> storage = [bucket.storage threadSafeStorage];
    id<SPDiffable> object = [storage objectForKey:key bucketName:bucket.name];
    
    // If the object no longer exists, it was likely previously deleted, in which case this change is no longer
    // relevant
    if (!object) {
        //DDLogWarn(@"Simperium warning: couldn't processLocalObjectWithKey %@ because the object no longer exists", key);
        [changesPending removeObjectForKey:key];
        [keysForObjectsWithMoreChanges removeObject:key];
        [self serializeChangesPending];
        [self serializeKeysForObjectsWithMoreChanges];
        return nil;
    }
    
    // If there are already changes pending for this entity, mark this entity and come back to it later to get the changes
    if (([changesPending objectForKey:object.simperiumKey] != nil) || later) {
        DDLogVerbose(@"Simperium marking object for sending more changes when ready (%@): %@", bucket.name, object.simperiumKey);
        [keysForObjectsWithMoreChanges addObject:[object simperiumKey]];
        [self serializeKeysForObjectsWithMoreChanges];
        return nil;
    }
    
    NSDictionary *change, *newData;
    DDLogVerbose(@"Simperium processing local object changes (%@): %@", bucket.name, object.simperiumKey); 
    
    if (object.ghost != nil && [object.ghost memberData] != nil)
    {
        // This object has already been synced in the past and has a server ghost, so we're
        // modifying the object
        
        // Get a diff of the object (in dictionary form)
        newData = [bucket.differ diff:object withDictionary: [object.ghost memberData]];
        DDLogVerbose(@"Simperium entity diff found %d changed members", [newData count]);
        if ([newData count] > 0) {
            change = [self createChangeForKey: object.simperiumKey operation: CH_MODIFY version:object.ghost.version data: newData];
        } else {
            // No difference, don't do anything else
            DDLogVerbose(@"Simperium warning: no difference in call to sendChanges (%@): %@", bucket.name, object.simperiumKey);
            return nil;
        }
        
    } else /*if (!entity.deleted)*/ {
        DDLogVerbose(@"Simperium local ADD detected, creating diff...");
        
        newData = [bucket.differ diffForAddition:object];
        change = [self createChangeForKey: object.simperiumKey operation:CH_MODIFY version: object.ghost.version data: newData];
    }
        
    // Check for any changes to binary members, in which case a file needs to be uploaded
//    SPEntityDefinition *entityDefinition = [objectManager definitionForEntityName: entityClassName];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        for (SPMemberBinary *binaryMember in entityDefinition.binaryMembers) {
//            NSDictionary *binaryDict = [newData objectForKey:binaryMember.keyName];
//            NSString *binaryFilename = [binaryDict objectForKey:CH_VALUE];
//            if (binaryFilename) {
//                [simperium.binaryManager startUploading:binaryFilename];
//            }
//        }
//    });
    
    return change;
}

-(NSArray *)processPendingChanges:(SPBucket *)bucket
{
    // Check if there are more changes that need to be sent
    if ([keysForObjectsWithMoreChanges count] > 0) {
        DDLogVerbose(@"Simperium found %u objects with more changes to send (%@)", [keysForObjectsWithMoreChanges count], bucket.name);
        // TODO: Robust handling of offline deletions
      
        NSMutableSet *keysProcessed = [NSMutableSet setWithCapacity:[keysForObjectsWithMoreChanges count]];
        NSMutableSet *pendingKeys = [NSMutableSet setWithCapacity:[keysForObjectsWithMoreChanges count]];
      
        //Create a list of the keys to be processed
        for (NSString *key in keysForObjectsWithMoreChanges) {
            // If there are already changes pending, don't add any more
            // Importantly, this prevents a potential mutation of keysForObjectsWithMoreChanges in processLocalObjectWithKey:later:
            if ([changesPending objectForKey: key] != nil)
                continue;
          
          [pendingKeys addObject:key];
        }
      
        // Create changes for any objects that have more changes
        [pendingKeys enumerateObjectsUsingBlock:^(NSString *key, BOOL *stop) {
          NSDictionary *change = [self processLocalObjectWithKey:key bucket:bucket later:NO];
          
          if (change)
              [changesPending setObject:change forKey: key];
          
          [keysProcessed addObject:key];
        }];
      
      
        // Clear any keys that were processed into pending changes
        [keysForObjectsWithMoreChanges minusSet:keysProcessed];
    }

    [self serializeChangesPending];
    [self serializeKeysForObjectsWithMoreChanges];
    
    return [changesPending allValues];
}

-(NSArray *)processKeysForObjectsWithMoreChanges:(SPBucket *)bucket
{
    // Check if there are more changes that need to be sent
    NSMutableArray *newChangesPending = [NSMutableArray arrayWithCapacity:3];
    if ([keysForObjectsWithMoreChanges count] > 0) {
        DDLogVerbose(@"Simperium found %u objects with more changes to send (%@)", [keysForObjectsWithMoreChanges count], bucket.name);
        
        NSMutableSet *keysProcessed = [NSMutableSet setWithCapacity:[keysForObjectsWithMoreChanges count]];
        // Create changes for any objects that have more changes
        for (NSString *key in keysForObjectsWithMoreChanges) {
            // If there are already changes pending, don't add any more
            // Importantly, this prevents a potential mutation of keysForObjectsWithMoreChanges in processLocalObjectWithKey:later:
            if ([changesPending objectForKey: key] != nil)
                continue;
            
            NSDictionary *change = [self processLocalObjectWithKey:key bucket:bucket later:NO];
            
            if (change) {
                [changesPending setObject:change forKey: key];
                [newChangesPending addObject:change];
            }
            [keysProcessed addObject:key];
        }
        // Clear any keys that were processed into pending changes
        [keysForObjectsWithMoreChanges minusSet:keysProcessed];
    }
    
    [self serializeChangesPending];
    [self serializeKeysForObjectsWithMoreChanges];
    
    // TODO: to fix duplicate send, make this return only changes for keysProcessed?
    return newChangesPending;
}


-(int)numChangesPending {
    return [changesPending count];
}

-(int)numKeysForObjectsWithMoreChanges {
    return [keysForObjectsWithMoreChanges count];
}

@end
