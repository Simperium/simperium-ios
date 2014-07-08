//
//  SPRelationshipResolver.m
//  Simperium
//
//  Created by Michael Johnston on 2012-08-22.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPRelationshipResolver+Internals.h"
#import "SPDiffable.h"
#import "SPStorage.h"
#import "SPStorageProvider.h"
#import "JSONKit+Simperium.h"
#import "SPGhost.h"
#import "SPLogger.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString * const SPRelationshipsPendingsLegacyKey    = @"SPPendingReferences";
static NSString * const SPRelationshipsPendingsNewKey       = @"SPRelationshipsPendingsNewKey";

static SPLogLevels logLevel                                 = SPLogLevelsInfo;


#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPRelationshipResolver()

@property (nonatomic, strong) dispatch_queue_t      queue;
@property (nonatomic, strong) NSHashTable           *pendingRelationships;
@property (nonatomic, strong) NSMapTable            *directMap;
@property (nonatomic, strong) NSMapTable            *inverseMap;

@end


#pragma mark ====================================================================================
#pragma mark SPRelationshipResolver
#pragma mark ====================================================================================

@implementation SPRelationshipResolver

- (id)init {
    self = [super init];
    if (self) {
        NSString *queueLabel    = [@"com.simperium." stringByAppendingString:[[self class] description]];
        _queue                  = dispatch_queue_create([queueLabel cStringUsingEncoding:NSUTF8StringEncoding], NULL);
        
        _pendingRelationships   = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];
        _directMap              = [NSMapTable strongToStrongObjectsMapTable];
        _inverseMap             = [NSMapTable strongToStrongObjectsMapTable];
    }
    
    return self;
}

- (void)migrateLegacyReferences:(id<SPStorageProvider>)storage {
    
    // Do we need to migrate anything?
    NSDictionary *legacyPendings = storage.metadata[SPRelationshipsPendingsLegacyKey];
    if (legacyPendings == nil) {
        return;
    }
    
    // Parse the old format first
    NSArray *parsed = [SPRelationship parseFromLegacyDictionary:legacyPendings];

    for (SPRelationship *relationship in parsed) {
        [self addPendingRelationship:relationship];
    }
    
    // Update the metadata
    NSArray *serialized             = [SPRelationship serializeToArray:[self.pendingRelationships allObjects]];
    NSMutableDictionary *updated    = [storage.metadata mutableCopy];
    [updated removeObjectForKey:SPRelationshipsPendingsLegacyKey];
    [updated setObject:serialized forKey:SPRelationshipsPendingsNewKey];
    [storage setMetadata:updated];
}


#pragma mark ====================================================================================
#pragma mark NEW Bidirectional API
#pragma mark ====================================================================================

- (void)loadPendingRelationships:(id<SPStorageProvider>)storage {
    
    NSAssert(storage, @"Invalid Parameter");
    NSAssert([NSThread isMainThread], @"Invalid Thread");
    
    // Migrate Legacy
    [self migrateLegacyReferences:storage];
    
    // Load stored descriptors in memory
	NSArray *rawPendings    = storage.metadata[SPRelationshipsPendingsNewKey];
    NSArray *parsedPendings = [SPRelationship parseFromArray:rawPendings];
    
    for (SPRelationship *relationship in parsedPendings) {
        [self addPendingRelationship:relationship];
    }
}

- (void)addPendingRelationship:(SPRelationship *)relationship {
    
    NSAssert([relationship isKindOfClass:[SPRelationship class]], @"Invalid Parameter");
    NSAssert([NSThread isMainThread], @"Invalid Thread");
        
    // Store the Relationship itself
    [self.pendingRelationships addObject:relationship];
    
    // Map the relationship: we want Direct + Inverse mapping!
    [self addRelationship:relationship inMap:self.directMap withKey:relationship.sourceKey];
    [self addRelationship:relationship inMap:self.inverseMap withKey:relationship.targetKey];
}

- (void)resolvePendingRelationshipsForKey:(NSString *)simperiumKey
                               bucketName:(NSString *)bucketName
                                  storage:(id<SPStorageProvider>)storage {

    [self resolvePendingRelationshipsForKey:simperiumKey
                                 bucketName:bucketName
                                    storage:storage
                                 completion:nil];
}

- (void)resolvePendingRelationshipsForKey:(NSString *)simperiumKey
                               bucketName:(NSString *)bucketName
                                  storage:(id<SPStorageProvider>)storage
                               completion:(SPResolverCompletionBlockType)completion {

    NSAssert([simperiumKey isKindOfClass:[NSString class]], @"Invalid Parameter");
    NSAssert([bucketName isKindOfClass:[NSString class]],   @"Invalid Parameter");
    NSAssert([NSThread isMainThread],                       @"Invalid Thread");
    
    NSHashTable *relationships = [self relationshipsForKey:simperiumKey];
    if (relationships.count == 0) {
        return;
    }
    
    // Resolve the references but do it in the background
    dispatch_async(self.queue, ^{
        id<SPStorageProvider> threadSafeStorage = [storage threadSafeStorage];
        [threadSafeStorage beginSafeSection];
        
        NSHashTable *processed = [NSHashTable hashTableWithOptions:NSHashTableStrongMemory];
        
        for (SPRelationship *relationship in relationships) {

            // Infer the targetBucket: 'Legacy' descriptors didn't store the targetBucket
            NSString *targetBucket = relationship.targetBucket;
            
            if (!targetBucket) {
                if ([simperiumKey isEqualToString:relationship.targetKey]) {
                    targetBucket = bucketName;
                } else {
                    // Unhandled scenario: There is no way to determine the targetBucket!
                    continue;
                }
            }
            
            id<SPDiffable>sourceObject  = [threadSafeStorage objectForKey:relationship.sourceKey bucketName:relationship.sourceBucket];
            id<SPDiffable>targetObject  = [threadSafeStorage objectForKey:relationship.targetKey bucketName:targetBucket];
            
            if (!sourceObject || !targetObject) {
                continue;
            }

            SPLogVerbose(@"Simperium resolving pending reference for %@.%@=%@",
                         relationship.sourceKey, relationship.sourceAttribute, relationship.targetKey);
            
            [sourceObject simperiumSetValue:targetObject forKey:relationship.sourceAttribute];
            
            // Get the key reference into the ghost as well
            [sourceObject.ghost.memberData setObject:relationship.targetKey forKey:relationship.sourceAttribute];
            sourceObject.ghost.needsSave = YES;
            
            // Cleanup!
            [processed addObject:relationship];
        }
        
        if (processed.count) {
            [threadSafeStorage save];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                @autoreleasepool {
                    [self removeRelationships:processed];
                    [self saveWithStorage:storage];
                }
            });
        }
        
        [threadSafeStorage finishSafeSection];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

- (void)saveWithStorage:(id<SPStorageProvider>)storage {
    
    NSAssert([storage conformsToProtocol:@protocol(SPStorageProvider)], @"Invalid Storage");
    NSAssert([NSThread isMainThread], @"Invalid Thread");
    
    NSDictionary *metadata = [storage metadata];
    
    // If there's already nothing there, save some CPU by not writing anything
    if (self.pendingRelationships.count == 0 && metadata[SPRelationshipsPendingsNewKey] == nil) {
        return;
    }
    
    NSArray *serialized                     = [SPRelationship serializeToArray:[self.pendingRelationships allObjects]];
    NSMutableDictionary *updated            = [metadata mutableCopy];
    updated[SPRelationshipsPendingsNewKey]  = serialized;
    [storage setMetadata:updated];
}

- (void)reset:(id<SPStorageProvider>)storage {
    
    // Nuke everything
    [self.pendingRelationships removeAllObjects];
    [self.directMap removeAllObjects];
    [self.inverseMap removeAllObjects];
    [self saveWithStorage:storage];
    
    // At last!
    [storage save];
}


#pragma mark ====================================================================================
#pragma mark Private Helpers
#pragma mark ====================================================================================

- (NSHashTable *)relationshipsForKey:(NSString *)simperiumKey {
    
    NSAssert([simperiumKey isKindOfClass:[NSString class]], @"Invalid Parameter");
    NSAssert([NSThread isMainThread],                       @"Invalid Thread");
    
    // Lookup relationships [From + To] this object
    NSHashTable *relationships = [NSHashTable weakObjectsHashTable];
    [relationships unionHashTable:[self.directMap objectForKey:simperiumKey]];
    [relationships unionHashTable:[self.inverseMap objectForKey:simperiumKey]];
    
    return relationships;
}

- (void)addRelationship:(SPRelationship *)relationship inMap:(NSMapTable *)map withKey:(NSString *)key {
    
    NSAssert([relationship isKindOfClass:[SPRelationship class]],   @"Invalid Parameter");
    NSAssert([map isKindOfClass:[NSMapTable class]],                @"Invalid Parameter");
    NSAssert([key isKindOfClass:[NSString class]],                  @"Invalid Parameter");
    
    NSHashTable *pendings = [map objectForKey:key];
    if (!pendings) {
        pendings = [NSHashTable weakObjectsHashTable];
        [map setObject:pendings forKey:key];
    }
    
    [pendings addObject:relationship];
}

- (void)removeRelationships:(NSHashTable *)relationships {
    
    NSAssert([relationships isKindOfClass:[NSHashTable class]],  @"Invalid Parameter");
    NSAssert([NSThread isMainThread], @"Invalid Thread");
    
    [self.pendingRelationships minusHashTable:relationships];
    
    // Note: Although we've set up internal structures with weak memory management, since there the
    // autoreleasepool will be drained by iOS at will, we really need to cleanup the directMap + inverseMap collections
    for (SPRelationship *relationship in relationships) {
        [self removeRelationship:relationship fromMap:self.directMap withKey:relationship.sourceKey];
        [self removeRelationship:relationship fromMap:self.inverseMap withKey:relationship.targetKey];
    }
}

- (void)removeRelationship:(SPRelationship *)relationship fromMap:(NSMapTable *)map withKey:(NSString *)key {
    NSHashTable *table = [map objectForKey:key];
    [table removeObject:relationship];
    
    if (table.count == 0) {
        [map removeObjectForKey:key];
    }
}


#pragma mark ====================================================================================
#pragma mark Debug Helpers
#pragma mark ====================================================================================

#ifdef DEBUG

- (NSInteger)countPendingRelationships {
    return self.pendingRelationships.count;
}

- (NSInteger)countPendingRelationshipsWithSourceKey:(NSString *)sourceKey
                                       andTargetKey:(NSString *)targetKey {
    
    return [self countPendingRelationshipWithSourceKey:sourceKey targetKey:targetKey inTable:self.pendingRelationships];
}

- (NSInteger)countPendingRelationshipWithSourceKey:(NSString *)sourceKey
                                         targetKey:(NSString *)targetKey
                                           inTable:(NSHashTable *)table {
    
    NSInteger count = 0;
    for (SPRelationship *relationship in table) {
        if ([relationship.sourceKey isEqualToString:sourceKey] && [relationship.targetKey isEqualToString:targetKey]) {
            ++count;
        }
    }
    
    return count;
}

- (BOOL)verifyBidirectionalMappingBetweenKey:(NSString *)sourceKey
                                      andKey:(NSString *)targetKey {
    
    NSHashTable *directTable    = [self.directMap objectForKey:sourceKey];
    NSHashTable *inverseTable   = [self.inverseMap objectForKey:targetKey];
    
    NSInteger directCount       = [self countPendingRelationshipWithSourceKey:sourceKey targetKey:targetKey inTable:directTable];
    NSInteger inverseCount      = [self countPendingRelationshipWithSourceKey:sourceKey targetKey:targetKey inTable:inverseTable];
    
    NSAssert(directCount == inverseCount, @"Inconsistency");
    
    return (directCount == inverseCount && inverseCount == 1);
}

#endif

@end
