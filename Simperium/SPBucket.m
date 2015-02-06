//
//  SPBucket.m
//  Simperium
//
//  Created by Michael Johnston on 12-04-12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPBucket+Internals.h"
#import "SPDiffable.h"
#import "SPDiffer.h"
#import "SPStorage.h"
#import "SPSchema.h"
#import "SPNetworkInterface.h"
#import "SPChangeProcessor.h"
#import "SPIndexProcessor.h"
#import "SPGhost.h"
#import "JSONKit+Simperium.h"
#import "SPRelationshipResolver.h"



@implementation SPBucket

@synthesize lastChangeSignature = _lastChangeSignature;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithSchema:(SPSchema *)aSchema
                       storage:(id<SPStorageProvider>)aStorage
              networkInterface:(id<SPNetworkInterface>)netInterface
          relationshipResolver:(SPRelationshipResolver *)resolver
                         label:(NSString *)label
                    remoteName:(NSString *)remoteName
                      clientID:(NSString *)clientID
{
    self = [super init];
    if (self) {
        _name                               = aSchema.bucketName;
        _remoteName                         = remoteName;
        _storage                            = aStorage;
        _network                            = netInterface;
        _relationshipResolver               = resolver;
        _propertyMismatchFailsafeEnabled    = false;
        
        SPDiffer *aDiffer                   = [[SPDiffer alloc] initWithSchema:aSchema];
        _differ                             = aDiffer;

        // Label is used to support multiple simperium instances (e.g. unit testing)
        _instanceLabel                      = [NSString stringWithFormat:@"%@%@", self.name, label];

        SPChangeProcessor *cp               = [[SPChangeProcessor alloc] initWithLabel:self.instanceLabel clientID:clientID];
        _changeProcessor                    = cp;

        SPIndexProcessor *ip                = [[SPIndexProcessor alloc] init];
        _indexProcessor                     = ip;

        NSString *queueLabel                = [@"com.simperium.processor." stringByAppendingString:self.name];
        _processorQueue                     = dispatch_queue_create([queueLabel cStringUsingEncoding:NSUTF8StringEncoding], NULL);

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
        [nc addObserver:self selector:@selector(objectDidChange:)            name:ProcessorDidChangeObjectNotification          object:self];
        [nc addObserver:self selector:@selector(objectsAdded:)               name:ProcessorDidAddObjectsNotification            object:self];
        [nc addObserver:self selector:@selector(objectKeysDeleted:)          name:ProcessorDidDeleteObjectKeysNotification      object:self];
        [nc addObserver:self selector:@selector(objectsAcknowledged:)        name:ProcessorDidAcknowledgeObjectsNotification    object:self];
        [nc addObserver:self selector:@selector(objectsWillChange:)          name:ProcessorWillChangeObjectsNotification        object:self];
        [nc addObserver:self selector:@selector(acknowledgedObjectDeletion:) name:ProcessorDidAcknowledgeDeleteNotification     object:self];
    }
    
    return self;
}

- (id)objectForKey:(NSString *)simperiumKey {
    // Typically used on startup to get a dictionary from storage; Simperium doesn't keep it in memory though
    id<SPDiffable>diffable = [self.storage objectForKey:simperiumKey bucketName:self.name];
    return [diffable object];
}

- (id)objectAtIndex:(NSUInteger)index {
    id<SPDiffable>diffable = [self.storage objectAtIndex:index bucketName:self.name];
    return [diffable object];
}

- (void)requestVersions:(int)numVersions key:(NSString *)simperiumKey {
    id<SPDiffable>diffable = [self.storage objectForKey:simperiumKey bucketName:self.name];
    [self.network requestVersions:numVersions object:diffable];
}

- (NSArray *)allObjects {
    return [self.storage objectsForBucketName:self.name predicate:nil];
}

- (NSArray *)allObjectKeys {
    return [self.storage objectKeysForBucketName:self.name];
}

- (id)insertNewObject {
    id<SPDiffable>diffable = [self.storage insertNewObjectForBucketName:self.name simperiumKey:nil];
    diffable.bucket = self;
    return [diffable object];
}

- (id)insertNewObjectForKey:(NSString *)simperiumKey {
    id<SPDiffable>diffable = [self.storage insertNewObjectForBucketName:self.name simperiumKey:simperiumKey];
    diffable.bucket = self;
    return [diffable object];
}

- (void)deleteObject:(id)object {
    [self.storage deleteObject:object];
}

- (void)deleteAllObjects {
    [self.storage deleteAllObjectsForBucketName:self.name];
}

- (void)validateObjects {
    // Allow the storage to determine the most efficient way to validate everything
    [self.storage validateObjectsForBucketName:self.name];
    [self.storage save];
}

- (void)unloadAllObjects {
    [self.storage unloadAllObjects];
    [self.relationshipResolver reset:self.storage];
}

- (NSArray *)objectsForKeys:(NSSet *)keys {
    return [self.storage objectsForKeys:keys bucketName:self.name];
}

- (NSArray *)objectsForPredicate:(NSPredicate *)predicate {
    return [self.storage objectsForBucketName:self.name predicate:predicate];
}

- (NSInteger)numObjects {
    return [self.storage numObjectsForBucketName:self.name predicate:nil];
}

- (NSInteger)numObjectsForPredicate:(NSPredicate *)predicate {
    return [self.storage numObjectsForBucketName:self.name predicate:predicate];
}

- (void)statsWithCallback:(SPBucketStatsCallback)callback {
    SPChangeProcessor *processor = self.changeProcessor;
    dispatch_async(self.processorQueue, ^{
        NSUInteger numPendingChanges    = processor.numChangesPending;
        NSUInteger numEnqueuedChanges   = processor.numKeysForObjectsWithMoreChanges;
        NSUInteger numEnqueuedDeletions = processor.numKeysForObjectToDelete;

        dispatch_async(dispatch_get_main_queue(), ^{
            callback(self, numPendingChanges, numEnqueuedChanges, numEnqueuedDeletions);
        });
    });
}

- (NSString *)lastChangeSignature {
    if (!_lastChangeSignature) {
        // Load it
        NSString *sigKey = [NSString stringWithFormat:@"lastChangeSignature-%@", self.instanceLabel];
        NSString *signature = [[NSUserDefaults standardUserDefaults] objectForKey:sigKey];
        _lastChangeSignature = [signature copy];
    }
    return _lastChangeSignature;
}

- (void)setLastChangeSignature:(NSString *)signature {
    _lastChangeSignature = [signature copy];
    
    // Persist it
    NSString *sigKey = [NSString stringWithFormat:@"lastChangeSignature-%@", self.instanceLabel];
    [[NSUserDefaults standardUserDefaults] setObject:_lastChangeSignature forKey: sigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


#pragma mark Notifications

- (void)objectDidChange:(NSNotification *)notification {
    if ([self.delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:memberNames:)]) {
        // Only one object changed; get it
        NSSet *set = (NSSet *)notification.userInfo[@"keys"];
        NSString *key = [[set allObjects] objectAtIndex:0];
        NSArray *changedMembers = (NSArray *)[notification.userInfo objectForKey:@"changedMembers"];
        [self.delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeUpdate memberNames:changedMembers];
    }
}

- (void)objectsAdded:(NSNotification *)notification {
    // When objects are added, resolve any references to them that hadn't yet been fulfilled
    // Note: this notification isn't currently triggered from SPIndexProcessor when adding objects from the index. Instead,
    // references are resolved from within SPIndexProcessor itself
    NSSet *set = (NSSet *)notification.userInfo[@"keys"];
    [self resolvePendingRelationshipsToKeys:set];

    // Also notify the delegate since the referenced objects are now accessible
    if ([self.delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:memberNames:)]) {
        for (NSString *key in set) {
            [self.delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeInsert memberNames:nil];
        }
    }
}

- (void)objectKeysDeleted:(NSNotification *)notification  {
    NSSet *set = (NSSet *)notification.userInfo[@"keys"];
    BOOL delegateRespondsToSelector = [self.delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:memberNames:)];

    for (NSString *key in set) {
        [self.storage stopManagingObjectWithKey:key];
        if (delegateRespondsToSelector) {
            [self.delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeDelete memberNames:nil];
        }
    }
}

- (void)objectsAcknowledged:(NSNotification *)notification  {
    if ([self.delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:memberNames:)]) {
        NSSet *set = (NSSet *)notification.userInfo[@"keys"];
        for (NSString *key in set) {
            [self.delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeAcknowledge memberNames:nil];
        }
    }
}

- (void)objectsWillChange:(NSNotification *)notification  {
    if ([self.delegate respondsToSelector:@selector(bucket:willChangeObjectsForKeys:)]) {
        NSSet *set = (NSSet *)notification.userInfo[@"keys"];
        [self.delegate bucket:self willChangeObjectsForKeys:set];
    }
}

- (void)acknowledgedObjectDeletion:(NSNotification *)notification {
    if ([self.delegate respondsToSelector:@selector(bucketDidAcknowledgeDelete:)]) {
        [self.delegate bucketDidAcknowledgeDelete:self];
    }    
}

- (SPSchema *)schema {
    return self.differ.schema;
}

- (void)setSchema:(SPSchema *)aSchema {
    self.differ.schema = aSchema;
}

- (void)resolvePendingRelationshipsToKeys:(NSSet *)keys {
    for (NSString *key in keys) {
        [self.relationshipResolver resolvePendingRelationshipsForKey:key bucketName:self.name storage:self.storage];
    }
}

- (void)forceSyncWithCompletion:(SPBucketForceSyncCompletion)completion {
    self.forceSyncCompletion    = completion;
    self.forceSyncSignature     = self.lastChangeSignature;
    [self.network forceSyncBucket:self];
}

- (BOOL)isForceSyncPending {
    return self.forceSyncCompletion != nil;
}

- (void)signalForceSyncComplete {
    if (!self.forceSyncCompletion) {
        return;
    }
    
    // New Data: Did the signature change?
    BOOL signatureUpdated = ![self.lastChangeSignature isEqualToString:self.forceSyncSignature];
    self.forceSyncCompletion(signatureUpdated);
    
    // Cleanup
    self.forceSyncCompletion    = nil;
    self.forceSyncSignature     = nil;
}

- (BOOL)hasLocalChangesForKey:(NSString *)key {
    return [self.changeProcessor hasLocalChangesForKey:key];
}

- (NSDictionary*)exportStatus {
    // This routine shall be used for debugging purposes!
    NSString* signature = self.lastChangeSignature ?: @"";
    return @{
        @"current"  : signature,
        @"index"    : [self.indexProcessor exportIndexStatus:self],
        @"pendings" : [self.changeProcessor exportPendingChanges]
    };
}

@end
