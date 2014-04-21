//
//  SPRelationshipResolverTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 4/17/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SPRelationshipResolver.h"
#import "MockStorage.h"
#import "XCTestCase+Simperium.h"
#import "NSString+Simperium.h"
#import "SPObject.h"


#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString *SPTestSourceBucket     = @"SPMockSource";
static NSString *SPTestSourceAttribute  = @"sourceAttribute";

static NSString *SPTestTargetBucket     = @"SPMockTarget";
static NSString *SPTestTargetAttribute1 = @"targetAttribute1";
static NSString *SPTestTargetAttribute2 = @"targetAttribute2";

static NSString *SPLegacyPathKey        = @"SPPathKey";
static NSString *SPLegacyPathBucket     = @"SPPathBucket";
static NSString *SPLegacyPathAttribute  = @"SPPathAttribute";
static NSString *SPLegacyPendingsKey    = @"SPPendingReferences";

static NSInteger SPTestIterations       = 100;
static NSInteger SPTestSubIterations    = 10;


#pragma mark ====================================================================================
#pragma mark Interface
#pragma mark ====================================================================================

@interface SPRelationshipResolverTests : XCTestCase
@property (nonatomic, strong) SPRelationshipResolver    *resolver;
@property (nonatomic, strong) MockStorage               *storage;
@end


#pragma mark ====================================================================================
#pragma mark SPRelationshipResolverTests!
#pragma mark ====================================================================================

@implementation SPRelationshipResolverTests

- (void)setUp
{
    [super setUp];
    self.resolver   = [SPRelationshipResolver new];
    self.storage    = [MockStorage new];
}

- (void)testSetPendingRelationships {
    
    // Set 'SPTestIterations' pending relationships
    NSMutableArray *sourceKeys = [NSMutableArray array];
    NSMutableArray *targetKeys = [NSMutableArray array];
    
    for (NSInteger i = 0; ++i <= SPTestIterations; ) {
        NSString *sourceKey = [NSString sp_makeUUID];
        NSString *targetKey = [NSString sp_makeUUID];

        [self.resolver setPendingRelationshipBetweenKey:sourceKey fromAttribute:SPTestSourceAttribute inBucket:SPTestSourceBucket
                                          withTargetKey:targetKey andTargetBucket:SPTestTargetBucket storage:self.storage];
        
        [sourceKeys addObject:sourceKey];
        [targetKeys addObject:targetKey];
    }
    
    // Verify
    XCTAssert( [self.resolver countPendingRelationships] == SPTestIterations, @"Inconsistency Detected" );

    for (NSInteger i = 0; ++i < SPTestIterations; ) {
        NSString *sourceKey = sourceKeys[i];
        NSString *targetKey = targetKeys[i];

        XCTAssertTrue( [self.resolver verifyBidireccionalMappingBetweenKey:sourceKey andKey:targetKey], @"Error in bidirectional mapping" );
        XCTAssertTrue( [self.resolver countPendingRelationshipsWithSourceKey:sourceKey andTargetKey:targetKey] == 1, @"Error while checking pending relationships" );
    }
    
    XCTAssertTrue( [self.resolver countPendingRelationships] == SPTestIterations, @"Inconsitency Detected" );
}

- (void)testLoadingPendingRelationships {
    
    // Set 'SPTestIterations' pending relationships
    NSMutableArray *sourceKeys = [NSMutableArray array];
    NSMutableArray *targetKeys = [NSMutableArray array];
    
    for (NSInteger i = 0; ++i <= SPTestIterations; ) {
        NSString *sourceKey = [NSString sp_makeUUID];
        NSString *targetKey = [NSString sp_makeUUID];
        
        [self.resolver setPendingRelationshipBetweenKey:sourceKey fromAttribute:SPTestSourceAttribute inBucket:SPTestSourceBucket
                                          withTargetKey:targetKey andTargetBucket:SPTestTargetBucket storage:self.storage];
        
        [sourceKeys addObject:sourceKey];
        [targetKeys addObject:targetKey];
    }
    
    // Save OP is async
    [self waitFor:1.0];
    
    // ""Simulate"" App Relaungh
    self.resolver = [SPRelationshipResolver new];
    [self.resolver loadPendingRelationships:self.storage];
    
    // Verify
    XCTAssert( [self.resolver countPendingRelationships] == SPTestIterations, @"Inconsistency found" );
    
    for (NSInteger i = 0; ++i < SPTestIterations; ) {
        NSString *sourceKey = sourceKeys[i];
        NSString *targetKey = targetKeys[i];
        
        XCTAssertTrue( [self.resolver verifyBidireccionalMappingBetweenKey:sourceKey andKey:targetKey], @"Error in bidirectional mapping" );
        XCTAssertTrue( [self.resolver countPendingRelationshipsWithSourceKey:sourceKey andTargetKey:targetKey] == 1, @"Error while checking pending relationships" );
    }
}

- (void)testMigrateLegacyRelationships {
    // Set 'SPTestIterations x SPTestIterations' pending legacy relationships
    NSMutableDictionary *legacy = [NSMutableDictionary dictionary];
    
    for (NSInteger i = 0; ++i <= SPTestIterations; ) {
        NSString *targetKey = [NSString sp_makeUUID];
    
        NSMutableArray *relationships = [NSMutableArray array];
        for (NSInteger j = 0; ++j <= SPTestSubIterations; ) {
            [relationships addObject: @{
                SPLegacyPathKey          : [NSString sp_makeUUID],
                SPLegacyPathBucket       : SPTestSourceBucket,
                SPLegacyPathAttribute    : SPTestSourceAttribute
                }];
        }
        
        legacy[targetKey] = relationships;
    }
    
    NSMutableDictionary *metadata   = [NSMutableDictionary dictionary];
    metadata[SPLegacyPendingsKey]   = legacy;
    self.storage.metadata           = metadata;

    // Sanity Check
    XCTAssertTrue( [self.resolver countPendingRelationships] == 0, @"Inconsistency Detected");
    
    // Load
    [self.resolver loadPendingRelationships:self.storage];
    
    XCTAssertTrue( [self.resolver countPendingRelationships] == SPTestIterations * SPTestSubIterations, @"Inconsistency Detected");
 
    // Verify
    for (NSString *targetKey in [legacy allKeys]) {
        
        for (NSDictionary *legacyDescriptor in legacy[targetKey]) {
            NSString *sourceKey = legacyDescriptor[SPLegacyPathKey];
            
            XCTAssertTrue( [self.resolver verifyBidireccionalMappingBetweenKey:sourceKey andKey:targetKey], @"Inconsistency Detected" );
            XCTAssertTrue( [self.resolver countPendingRelationshipsWithSourceKey:sourceKey andTargetKey:targetKey] == 1, @"Inconsistency Detected" );
        }
    }
}

- (void)testResetPendingRelationships {
    // Set SPTestIterations pendings
    for (NSInteger i = 0; ++i <= SPTestIterations; ) {
        NSString *sourceKey = [NSString sp_makeUUID];
        NSString *targetKey = [NSString sp_makeUUID];
        
        [self.resolver setPendingRelationshipBetweenKey:sourceKey fromAttribute:SPTestSourceAttribute inBucket:SPTestSourceBucket
                                          withTargetKey:targetKey andTargetBucket:SPTestTargetBucket storage:self.storage];
    }
    
    XCTAssertTrue( [self.resolver countPendingRelationships] == SPTestIterations, @"Inconsistency detected" );

    [self.resolver reset:self.storage];
    
    XCTAssertTrue( [self.resolver countPendingRelationships] == 0, @"Inconsistency detected" );
    
    // ""Simulate"" App Relaungh
    self.resolver = [SPRelationshipResolver new];
    [self.resolver loadPendingRelationships:self.storage];
    
    // After relaunch, relationships should be zero as well
    XCTAssertTrue( [self.resolver countPendingRelationships] == 0, @"Inconsistency detected" );
}

- (void)testInsertDuplicateRelationships {
    NSString *firstKey  = [NSString sp_makeUUID];
    NSString *secondKey = [NSString sp_makeUUID];

    for (NSInteger i = 0; ++i <= 2; ) {
        [self.resolver setPendingRelationshipBetweenKey:firstKey fromAttribute:SPTestSourceAttribute inBucket:SPTestSourceBucket
                                          withTargetKey:secondKey andTargetBucket:SPTestTargetBucket storage:self.storage];
    }
    
    XCTAssertTrue( [self.resolver countPendingRelationships] == 1, @"Inconsistency detected" );
}

- (void)testResolvePendingRelationshipWithMissingObject {
    // New Objects please
    SPObject *target            = [SPObject new];
    target.simperiumKey         = [NSString sp_makeUUID];
    
    SPObject *firstSource       = [SPObject new];
    firstSource.simperiumKey    = [NSString sp_makeUUID];

    SPObject *secondSource      = [SPObject new];
    secondSource.simperiumKey   = [NSString sp_makeUUID];

    // Set 4 pendings:  target >> firstSource + secondSource  ||  firstSource >> target  ||  secondSource >> target
    [self.resolver setPendingRelationshipBetweenKey:target.simperiumKey fromAttribute:SPTestTargetAttribute1 inBucket:SPTestTargetBucket
                                      withTargetKey:firstSource.simperiumKey andTargetBucket:SPTestSourceBucket storage:self.storage];

    [self.resolver setPendingRelationshipBetweenKey:target.simperiumKey fromAttribute:SPTestTargetAttribute2 inBucket:SPTestTargetBucket
                                      withTargetKey:secondSource.simperiumKey andTargetBucket:SPTestSourceBucket storage:self.storage];
    
    [self.resolver setPendingRelationshipBetweenKey:firstSource.simperiumKey fromAttribute:SPTestSourceAttribute inBucket:SPTestSourceBucket
                                      withTargetKey:target.simperiumKey andTargetBucket:SPTestTargetBucket storage:self.storage];
    
    [self.resolver setPendingRelationshipBetweenKey:secondSource.simperiumKey fromAttribute:SPTestSourceAttribute inBucket:SPTestSourceBucket
                                      withTargetKey:target.simperiumKey andTargetBucket:SPTestTargetBucket storage:self.storage];
    
    // Resolver works in a BG thread. Wait a sec...
    [self waitFor:1.0f];
    
    // Verify
    XCTAssertTrue( [self.resolver countPendingRelationships] == 4, @"Inconsistency detected" );
    XCTAssertTrue( [self.resolver verifyBidireccionalMappingBetweenKey:firstSource.simperiumKey andKey:target.simperiumKey], @"Inconsistency detected" );
    XCTAssertTrue( [self.resolver verifyBidireccionalMappingBetweenKey:secondSource.simperiumKey andKey:target.simperiumKey], @"Inconsistency detected" );
    XCTAssertTrue( [self.resolver verifyBidireccionalMappingBetweenKey:target.simperiumKey andKey:firstSource.simperiumKey], @"Inconsistency detected" );
    XCTAssertTrue( [self.resolver verifyBidireccionalMappingBetweenKey:target.simperiumKey andKey:firstSource.simperiumKey], @"Inconsistency detected" );
    
    // Insert Target
    [self.storage insertObject:target bucketName:SPTestTargetBucket];

    // NO-OP's
    [self.resolver resolvePendingRelationshipsForKey:target.simperiumKey bucketName:SPTestSourceBucket storage:self.storage];
    [self.resolver resolvePendingRelationshipsForKey:firstSource.simperiumKey bucketName:SPTestSourceBucket storage:self.storage];
    [self.resolver resolvePendingRelationshipsForKey:secondSource.simperiumKey bucketName:SPTestSourceBucket storage:self.storage];
    
    // Resolve OP is async
    [self waitFor:1.0f];
    
    // We should still have 4 relationships
    XCTAssertTrue( [self.resolver countPendingRelationships] == 4, @"Inconsistency detected" );
    
    // Insert First Source
    [self.storage insertObject:firstSource bucketName:SPTestSourceBucket];
    [self.resolver resolvePendingRelationshipsForKey:firstSource.simperiumKey bucketName:SPTestSourceBucket storage:self.storage];
    
    // Resolve OP is async
    [self waitFor:1.0f];
    [self.resolver resolvePendingRelationshipsForKey:firstSource.simperiumKey bucketName:SPTestSourceBucket storage:self.storage];
    // Verify
    XCTAssert([firstSource simperiumValueForKey:SPTestSourceAttribute] == target, @"Inconsistency detected" );
    XCTAssert([target simperiumValueForKey:SPTestTargetAttribute1] == firstSource, @"Inconsistency detected" );
    XCTAssertTrue( [self.resolver countPendingRelationships] == 2, @"Inconsistency detected" );
    XCTAssertFalse([self.resolver verifyBidireccionalMappingBetweenKey:target.simperiumKey andKey:firstSource.simperiumKey], @"Inconsistency detected");
    
    // Insert Second Source
    [self.storage insertObject:secondSource bucketName:SPTestSourceBucket];
    [self.resolver resolvePendingRelationshipsForKey:secondSource.simperiumKey bucketName:SPTestSourceBucket storage:self.storage];

    // Resolve OP is async
    [self waitFor:1.0f];
    
    // Verify
    XCTAssert([secondSource simperiumValueForKey:SPTestSourceAttribute] == target, @"Inconsistency detected" );
    XCTAssert([target simperiumValueForKey:SPTestTargetAttribute2] == secondSource, @"Inconsistency detected" );
    XCTAssertFalse([self.resolver verifyBidireccionalMappingBetweenKey:target.simperiumKey andKey:secondSource.simperiumKey], @"Inconsistency detected");
    XCTAssertTrue( [self.resolver countPendingRelationships] == 0, @"Inconsistency detected" );
}

@end
