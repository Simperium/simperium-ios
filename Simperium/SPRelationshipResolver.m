//
//  SPRelationshipResolver.m
//  Simperium
//
//  Created by Michael Johnston on 2012-08-22.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPRelationshipResolver.H"
#import "SPDiffable.h"
#import "SPStorage.h"
#import "SPStorageProvider.h"
#import "JSONKit+Simperium.h"
#import "SPGhost.h"
#import "SPLogger.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString * const SPRelationshipsSourceKey        = @"SPRelationshipsSourceKey";
static NSString * const SPRelationshipsSourceBucket     = @"SPRelationshipsSourceBucket";
static NSString * const SPRelationshipsSourceAttribute  = @"SPRelationshipsSourceAttribute";
static NSString * const SPRelationshipsTargetBucket     = @"SPRelationshipsTargetBucket";
static NSString * const SPRelationshipsTargetKey        = @"SPRelationshipsTargetKey";
static NSString * const SPRelationshipsPendingsNewKey   = @"SPRelationshipsPendingsNewKey";

static NSString * const SPLegacyPathKey                 = @"SPPathKey";
static NSString * const SPLegacyPathBucket              = @"SPPathBucket";
static NSString * const SPLegacyPathAttribute           = @"SPPathAttribute";
static NSString * const SPLegacyPendingsKey             = @"SPPendingReferences";

static SPLogLevels logLevel                             = SPLogLevelsInfo;


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
    if ((self = [super init])) {
        NSString *queueLabel        = [@"com.simperium." stringByAppendingString:[[self class] description]];
        self.queue                  = dispatch_queue_create([queueLabel cStringUsingEncoding:NSUTF8StringEncoding], NULL);
        
        self.pendingRelationships   = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory];
        self.directMap              = [NSMapTable strongToStrongObjectsMapTable];
        self.inverseMap             = [NSMapTable strongToStrongObjectsMapTable];
    }
    
    return self;
}

- (void)migrateLegacyReferences:(id<SPStorageProvider>)storage {
    
    // Do we need to migrate anything?
    NSDictionary *legacyPendings = storage.metadata[SPLegacyPendingsKey];
    if ( legacyPendings == nil ) {
        return;
    }
    
    // Migrate!
    for (NSString *targetKey in legacyPendings) {
        NSArray *relationships = legacyPendings[targetKey];
        NSAssert( [relationships isKindOfClass:[NSArray class]], @"Invalid Kind" );

        for (NSDictionary *relationship in relationships) {
            [self setPendingRelationshipBetweenKey:relationship[SPLegacyPathKey]
                                     fromAttribute:relationship[SPLegacyPathAttribute]
                                          inBucket:relationship[SPLegacyPathBucket]
                                     withTargetKey:targetKey
                                   andTargetBucket:nil
                                           storage:storage];
        }
    }
        
    // Nuke + Save
    NSMutableDictionary *updated = [storage.metadata mutableCopy];
    [updated removeObjectForKey:SPLegacyPendingsKey];
    [storage setMetadata:updated];
}


#pragma mark ====================================================================================
#pragma mark NEW Bidirectional API
#pragma mark ====================================================================================

- (void)loadPendingRelationships:(id<SPStorageProvider>)storage {
    
    NSAssert( storage, @"Invalid Parameter" );
    
    // Migrate Legacy
    [self migrateLegacyReferences:storage];
    
    // Load stored descriptors in memory
	NSArray *pendings = storage.metadata[SPRelationshipsPendingsNewKey];
    
    for (NSDictionary *descriptor in pendings) {
        NSAssert( [descriptor isKindOfClass:[NSDictionary class]], @"Invalid Parameter" );

        NSString *sourceKey = descriptor[SPRelationshipsSourceKey];
        NSString *targetKey = descriptor[SPRelationshipsTargetKey];

        [self addRelationshipDescriptor:descriptor sourceKey:sourceKey targetKey:targetKey];
    }
}

- (void)setPendingRelationshipBetweenKey:(NSString *)sourceKey
                           fromAttribute:(NSString *)sourceAttribute
                                inBucket:(NSString *)sourceBucket
                           withTargetKey:(NSString *)targetKey
                         andTargetBucket:(NSString *)targetBucket
                                 storage:(id<SPStorageProvider>)storage {
    
    NSAssert( sourceKey.length,         @"Invalid Parameter" );
    NSAssert( sourceAttribute.length,   @"Invalid Parameter" );
    NSAssert( sourceBucket.length,      @"Invalid Parameter" );
    NSAssert( targetKey.length,         @"Invalid Parameter" );
    NSAssert( storage,                  @"Invalid Parameter" );
    
    // Non-debug Failsafe
    if (targetKey.length == 0) {
        SPLogWarn(@"Simperium warning: received empty pending reference to attribute %@", sourceAttribute);
        return;
    }
    
    NSMutableDictionary *descriptor = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        sourceKey,          SPRelationshipsSourceKey,
        sourceAttribute,    SPRelationshipsSourceAttribute,
        sourceBucket,       SPRelationshipsSourceBucket,
        targetKey,          SPRelationshipsTargetKey,
    nil];
    
    // TargetBucket is optional. Why?: Legacy code wasn't storing that.
    // We'll need to reuse this method to load legacy relationships!
    if (targetBucket) {
        descriptor[SPRelationshipsTargetBucket] = targetBucket;
    }
    
    [self addRelationshipDescriptor:descriptor sourceKey:sourceKey targetKey:targetKey];
    [self saveRelationshipDescriptors:storage];
}

- (void)resolvePendingRelationshipsForKey:(NSString *)simperiumKey
                               bucketName:(NSString *)bucketName 
                                  storage:(id<SPStorageProvider>)storage {
    
    NSHashTable *relationships = [self relationshipDescriptorsForKey:simperiumKey];
    if (relationships.count == 0) {
        return;
    }
    
    // Resolve the references but do it in the background
    dispatch_async(self.queue, ^{
        id<SPStorageProvider> threadSafeStorage = [storage threadSafeStorage];
        [threadSafeStorage beginSafeSection];
        
        NSHashTable *processed = [NSHashTable hashTableWithOptions:NSHashTableStrongMemory];
        
        for (NSDictionary *descriptor in relationships) {

            // Unwrap
            NSString *sourceKey         = descriptor[SPRelationshipsSourceKey];
            NSString *sourceBucket      = descriptor[SPRelationshipsSourceBucket];
            NSString *sourceAttribute   = descriptor[SPRelationshipsSourceAttribute];
            NSString *targetKey         = descriptor[SPRelationshipsTargetKey];
            NSString *targetBucket      = descriptor[SPRelationshipsTargetBucket];
            
            // Infer the targetBucket: 'Legacy' descriptors didn't store the targetBucket
            if (!targetBucket) {
                if ([simperiumKey isEqualToString:targetKey]) {
                    targetBucket = bucketName;
                } else {
                    // Unhandled scenario: There is no way to determine the targetBucket!
                    continue;
                }
            }
            
            id<SPDiffable>sourceObject  = [threadSafeStorage objectForKey:sourceKey bucketName:sourceBucket];
            id<SPDiffable>targetObject  = [threadSafeStorage objectForKey:targetKey bucketName:targetBucket];
            
            if (!sourceObject || !targetObject) {
                continue;
            }

            SPLogVerbose(@"Simperium resolving pending reference for %@.%@=%@", sourceKey, sourceAttribute, targetKey);
            [sourceObject simperiumSetValue:targetObject forKey:sourceAttribute];
            
            // Get the key reference into the ghost as well
            [sourceObject.ghost.memberData setObject:targetKey forKey:sourceAttribute];
            sourceObject.ghost.needsSave = YES;
            
            // Cleanup!
            [processed addObject:descriptor];
        }
        
        if (processed.count) {
            [threadSafeStorage save];
            [self removeRelationshipDescriptors:processed];
            [self saveRelationshipDescriptors:storage];
        }
        
        [threadSafeStorage finishSafeSection];
    });
}

- (void)reset:(id<SPStorageProvider>)storage {
    
    // Nuke everything
    [self.pendingRelationships removeAllObjects];
    [self.directMap removeAllObjects];
    [self.inverseMap removeAllObjects];
    [self saveRelationshipDescriptors:storage];
    
    // At last!
    [storage save];
}


#pragma mark ====================================================================================
#pragma mark Private Helpers
#pragma mark ====================================================================================

- (void)saveRelationshipDescriptors:(id<SPStorageProvider>)storage {
    
    NSAssert( [storage conformsToProtocol:@protocol(SPStorageProvider)], @"Invalid Storage" );
    
    dispatch_block_t block = ^{
        NSDictionary *metadata = [storage metadata];
        
        // If there's already nothing there, save some CPU by not writing anything
        if ( self.pendingRelationships.count == 0 && metadata[SPRelationshipsPendingsNewKey] == nil ) {
            return;
        }
        
        NSMutableDictionary *updated = [metadata mutableCopy];
        updated[SPRelationshipsPendingsNewKey] = [self.pendingRelationships allObjects];
        [storage setMetadata:updated];
    };
    
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (NSHashTable *)relationshipDescriptorsForKey:(NSString *)simperiumKey {
    
    NSAssert( [simperiumKey isKindOfClass:[NSString class]], @"Invalid Parameter" );
    NSAssert( [NSThread isMainThread],                       @"Invalid Thread");
    
    // Lookup relationships [From + To] this object
    NSHashTable *relationships = [NSHashTable weakObjectsHashTable];
    [relationships unionHashTable:[self.directMap objectForKey:simperiumKey]];
    [relationships unionHashTable:[self.inverseMap objectForKey:simperiumKey]];
    
    return relationships;
}

- (void)addRelationshipDescriptor:(NSDictionary *)descriptor sourceKey:(NSString *)sourceKey targetKey:(NSString *)targetKey {
    
    NSAssert( [descriptor isKindOfClass:[NSDictionary class]],  @"Invalid Parameter" );
    NSAssert( [sourceKey isKindOfClass:[NSString class]],       @"Invalid Parameter" );
    NSAssert( [targetKey isKindOfClass:[NSString class]],       @"Invalid Parameter" );
    NSAssert( [NSThread isMainThread],                          @"Invalid Thread" );
    
    // Store the Relationship itself
    [self.pendingRelationships addObject:descriptor];
    
    // Map the relationship: we want Direct + Inverse mapping!
    [self addRelationship:descriptor inMap:self.directMap withKey:sourceKey];
    [self addRelationship:descriptor inMap:self.inverseMap withKey:targetKey];
}

- (void)addRelationship:(NSDictionary *)descriptor inMap:(NSMapTable *)map withKey:(NSString *)key {
    
    NSAssert( [descriptor isKindOfClass:[NSDictionary class]],  @"Invalid Parameter" );
    NSAssert( [map isKindOfClass:[NSMapTable class]],           @"Invalid Parameter" );
    NSAssert( [key isKindOfClass:[NSString class]],             @"Invalid Parameter" );
    
    NSHashTable *pendings = [map objectForKey:key];
    if (!pendings) {
        pendings = [NSHashTable weakObjectsHashTable];
        [map setObject:pendings forKey:key];
    }
    
    [pendings addObject:descriptor];
}

- (void)removeRelationshipDescriptors:(NSHashTable *)descriptors {
    
    NSAssert( [descriptors isKindOfClass:[NSHashTable class]],  @"Invalid Parameter" );
    
    dispatch_block_t block = ^{
        [self.pendingRelationships minusHashTable:descriptors];
        
        // Note: Although we've set up internal structures with weak memory management, since there the
        // autoreleasepool will be drained by iOS at will, we really need to cleanup the directMap + inverseMap collections
        for (NSDictionary *descriptor in descriptors) {
            NSString *sourceKey = descriptor[SPRelationshipsSourceKey];
            NSString *targetKey = descriptor[SPRelationshipsTargetKey];
            [self removeRelationship:descriptor fromMap:self.directMap withKey:sourceKey];
            [self removeRelationship:descriptor fromMap:self.inverseMap withKey:targetKey];
        }
    };
    
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)removeRelationship:(NSDictionary *)descriptor fromMap:(NSMapTable *)map withKey:(NSString *)key {
    NSHashTable *table = [map objectForKey:key];
    [table removeObject:descriptor];
    
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
    for (NSDictionary *descriptor in table) {
        if ( [descriptor[SPRelationshipsSourceKey] isEqualToString:sourceKey] &&
            [descriptor[SPRelationshipsTargetKey] isEqualToString:targetKey] ) {
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
