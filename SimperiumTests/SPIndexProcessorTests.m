//
//  SPIndexProcessorTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 6/18/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Simperium.h"
#import "MockSimperium.h"
#import "Simperium+Internals.h"
#import "SPBucket+Internals.h"
#import "SPGhost.h"
#import "SPIndexProcessor.h"
#import "SPStorageProvider.h"
#import "SPChangeProcessor.h"
#import "SPCoreDataStorage+Mock.h"
#import "Config.h"

#import "NSString+Simperium.h"
#import "JSONKit+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSInteger const SPNumberOfEntities           = 100;
static NSInteger const SPKeyLength                  = 10;
static NSInteger const SPLogLength                  = 50;
static NSTimeInterval const SPExpectationTimeout    = 60.0;


#pragma mark ====================================================================================
#pragma mark SPIndexProcessorTests
#pragma mark ====================================================================================

@interface SPIndexProcessorTests : XCTestCase
@property (nonatomic, strong) Simperium*            simperium;
@property (nonatomic, strong) SPCoreDataStorage*    storage;
@property (nonatomic, strong) SPBucket*             configBucket;
@end

@implementation SPIndexProcessorTests

- (void)setUp {
    [super setUp];

    self.simperium      = [MockSimperium mockSimperium];
    self.storage        = _simperium.coreDataStorage;
    self.configBucket   = [self.simperium bucketForName:NSStringFromClass([Config class])];

    // Make sure that we're not picking up old enqueued changes
    [self.configBucket.changeProcessor reset];
}

- (void)tearDown {
    [super tearDown];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Signout Expectation"];

    [self.simperium signOutAndRemoveLocalData:false completion:^{
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:nil];
}

- (void)testProcessVersionsWithoutPreexistingObjects {
    
    // ===================================================================================================
	// Helpers
    // ===================================================================================================
    //
	SPBucket* bucket = self.configBucket;
    
    
    // ===================================================================================================
    // Prepare Remote Entites Message (x SPNumberOfEntities)
    // ===================================================================================================
    //
    NSMutableArray *versions        = [NSMutableArray array];
    NSMutableDictionary *versionMap = [NSMutableDictionary dictionary];
    NSString *endVersion            = @"10";
    
    for (NSInteger i = 0; i < SPNumberOfEntities; ++i) {
    
        // Random Key
        NSString *key           = [NSString sp_randomStringOfLength:SPKeyLength];
        
        // Random Data
        NSString *log           = [NSString sp_randomStringOfLength:SPLogLength];
        NSDecimalNumber *cost   = [NSDecimalNumber decimalNumberWithString:endVersion];
        NSNumber *warp          = @(rand());
        
        // Marshall'ing
        NSDictionary *data = @{
            NSStringFromSelector(@selector(captainsLog))    : log,
            NSStringFromSelector(@selector(cost))           : cost,
            NSStringFromSelector(@selector(warpSpeed))      : warp,
        };
        
        [versions addObject:@[ key, endVersion, data ] ];
        versionMap[key] = data;
    }
    
    XCTAssertEqual(versions.count, SPNumberOfEntities, @"Error while generating versions");
    NSLog(@"<> Successfully generated versions");
    
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Index Processor Expectation"];
    
    dispatch_async(bucket.processorQueue, ^{
        
        [bucket.indexProcessor processVersions:versions bucket:bucket changeHandler:^(NSString *key) {
            XCTAssert(false, @"This should not get called");
        }];
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
    
    NSLog(@"<> Finished processing versions");
    
    
    // ===================================================================================================
    // Verify if the indexProcessor actually did its job
    // ===================================================================================================
    //
    NSArray *insertedConfigs = [bucket allObjects];
    XCTAssertEqual(insertedConfigs.count, SPNumberOfEntities, @"Error processing versions");
    
    for (Config *config in insertedConfigs) {
        
        NSDictionary *versionData       = versionMap[config.simperiumKey];
        NSString *expectedLog           = versionData[NSStringFromSelector(@selector(captainsLog))];
        NSDecimalNumber *expectedCost   = versionData[NSStringFromSelector(@selector(cost))];
        NSNumber *expectedWarp          = versionData[NSStringFromSelector(@selector(warpSpeed))];
        
        XCTAssert([config isKindOfClass:[Config class]],                                @"Invalid object kind");
        XCTAssertEqualObjects(config.captainsLog, expectedLog,                          @"Invalid Log");
        XCTAssertEqualObjects(config.cost, expectedCost,                                @"Invalid Cost");
        XCTAssertEqualObjects(config.warpSpeed, expectedWarp,                           @"Invalid Warp");
        XCTAssertTrue([self isGhostEqualToDictionary:versionData ghost:config.ghost],   @"Invalid Ghost MemberData");
    }
}

- (void)testProcessVersionsWithExistingObjectsAndZeroLocalPendingChanges {
    
    // ===================================================================================================
	// Testing values!
    // ===================================================================================================
    //
    NSString *originalLog           = @"1111 Captains Log";
    NSNumber *originalWarp          = @(29);
    NSDecimalNumber *originalCost   = [NSDecimalNumber decimalNumberWithString:@"100"];
    NSDate *originalDate            = [NSDate date];
    
    NSString *newRemoteLog          = @"2222 Captains Log";
    NSNumber *newRemoteWarp         = @(10);
    NSDecimalNumber *newRemoteCost  = [NSDecimalNumber decimalNumberWithString:@"300"];
    NSDate *newRemoteDate           = [NSDate date];
    
    
    // ===================================================================================================
	// Helpers
    // ===================================================================================================
    //
    SPBucket* bucket = self.configBucket;
    
    
    // ===================================================================================================
	// Insert Configs
    // ===================================================================================================
    //
    NSMutableArray *configs = [NSMutableArray array];
    
    for (NSInteger i = 0; i < SPNumberOfEntities; ++i) {
        Config* config                  = [self.storage insertNewObjectForBucketName:bucket.name simperiumKey:nil];
        config.captainsLog              = originalLog;
        config.warpSpeed                = originalWarp;
        config.cost                     = originalCost;
        config.date                     = originalDate;
        
        // Manually Intialize SPGhost: we're not relying on the backend to confirm these additions!
        NSMutableDictionary *memberData = [config.dictionary mutableCopy];
        SPGhost *ghost                  = [[SPGhost alloc] initWithKey:config.simperiumKey memberData:memberData];
        ghost.version                   = @"1";
        config.ghost                    = ghost;
        config.ghostData                = [memberData sp_JSONString];
        
        [configs addObject:config];
    }
    
	[self.storage save];
    
    NSLog(@"<> Successfully inserted Config object");
    
    
    // ===================================================================================================
    // Prepare Remote Entity Message
    // ===================================================================================================
    //
    NSMutableArray *versions        = [NSMutableArray array];
    NSMutableDictionary *versionMap = [NSMutableDictionary dictionary];
    NSString *endVersion            = @"930";
    
    NSDictionary *data              = @{
        NSStringFromSelector(@selector(captainsLog))    : newRemoteLog,
        NSStringFromSelector(@selector(cost))           : newRemoteCost,
        NSStringFromSelector(@selector(warpSpeed))      : newRemoteWarp,
        NSStringFromSelector(@selector(date))           : @(newRemoteDate.timeIntervalSince1970)
    };
    
    for (Config *config in configs) {
        
        [versions addObject:@[ config.simperiumKey, endVersion, data ] ];
        versionMap[config.simperiumKey] = data;
    }
    
    NSLog(@"<> Successfully generated versions");
    
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Index Processor Expectation"];
    
    dispatch_async(bucket.processorQueue, ^{
        
        [bucket.indexProcessor processVersions:versions bucket:bucket changeHandler:^(NSString *key) {
            XCTAssert(false, @"This should not get called");
        }];
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
    
    NSLog(@"<> Finished processing versions");
    
    
    // ===================================================================================================
    // Verify if the indexProcessor actually did its job
    // ===================================================================================================
    //
    [self.storage refaultObjects:configs];
    
    for (Config *config in configs) {
        NSDictionary *versionData = versionMap[config.simperiumKey];
        
        XCTAssertEqualObjects(config.captainsLog, newRemoteLog,                         @"Invalid Log");
        XCTAssertEqualObjects(config.cost, newRemoteCost,                               @"Invalid Cost");
        XCTAssertEqualObjects(config.warpSpeed, newRemoteWarp,                          @"Invalid Warp");
        XCTAssertEqualObjects(config.ghost.version, endVersion,                         @"Invalid Ghost Version");
        XCTAssertTrue([self isGhostEqualToDictionary:versionData ghost:config.ghost],   @"Invalid Ghost MemberData");
    }
}

- (void)testProcessVersionsWithExistingObjectsAndLocalPendingChangesSucceedsRebasing {
    
    // ===================================================================================================
	// Testing values!
    // ===================================================================================================
    //
    NSString *originalLog               = @"Original Captains Log";
    NSNumber *originalWarp              = @(29);
    NSDecimalNumber *originalCost       = [NSDecimalNumber decimalNumberWithString:@"100"];
    
    NSString *localPendingLog           = @"Something Original Captains Log";
    NSNumber *localPendingWarp          = @(31337);
    NSDecimalNumber *localPendingCost   = [NSDecimalNumber decimalNumberWithString:@"900"];
    
    NSString *newRemoteLog              = @"Remote Original Captains Log Suffixed";
    NSNumber *newRemoteWarp             = @(10);
    NSDecimalNumber *newRemoteCost      = [NSDecimalNumber decimalNumberWithString:@"300"];
    
    // We expect the strings to be merged. Numbers, on the other side, should remain with the local pending values.
    NSString *expectedLog               = @"Remote Something Original Captains Log Suffixed";
    NSNumber *expectedWarp              = localPendingWarp;
    NSDecimalNumber *expectedCost       = localPendingCost;
    
    
    // ===================================================================================================
	// Helpers
    // ===================================================================================================
    //
    SPBucket* bucket = self.configBucket;
    
    
    // ===================================================================================================
	// Insert Config
    // ===================================================================================================
    //
    Config* config                      = [self.storage insertNewObjectForBucketName:bucket.name simperiumKey:nil];
    config.captainsLog                  = originalLog;
    config.warpSpeed                    = originalWarp;
    config.cost                         = originalCost;
    
    NSString* configSimperiumKey        = config.simperiumKey;
    
    // ===================================================================================================
    // Manually Intialize SPGhost: we're not relying on the backend to confirm these additions!
    // ===================================================================================================
    //
    NSMutableDictionary *memberData     = [config.dictionary mutableCopy];
    SPGhost *ghost                      = [[SPGhost alloc] initWithKey:config.simperiumKey memberData:memberData];
    ghost.version                       = @"1";
    config.ghost                        = ghost;
    config.ghostData                    = [memberData sp_JSONString];
    
	[self.storage save];
    
    NSLog(@"<> Successfully inserted Config object");
    
    
    // ===================================================================================================
    // Prepare Remote Versions Message
    // ===================================================================================================
    //
    NSString *endVersion    = [NSString stringWithFormat:@"%d", config.ghost.version.intValue + 1];
    
    NSDictionary *data      = @{
        NSStringFromSelector(@selector(captainsLog))    : newRemoteLog,
        NSStringFromSelector(@selector(cost))           : newRemoteCost,
        NSStringFromSelector(@selector(warpSpeed))      : newRemoteWarp,
    };
    
    NSArray *versions       = @[ @[ config.simperiumKey, endVersion, data ] ];
    
    NSLog(@"<> Successfully generated versions");
    
    
    // ===================================================================================================
    // Set local pending changes
    // ===================================================================================================
    //
    config.captainsLog  = localPendingLog;
    config.warpSpeed    = localPendingWarp;
    config.cost         = localPendingCost;
    
    [self.storage save];
    
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Index Processor Expectation"];
    
    dispatch_async(bucket.processorQueue, ^{
        
        [bucket.indexProcessor processVersions:versions bucket:bucket changeHandler:^(NSString *key) {
            XCTAssertEqualObjects(key, configSimperiumKey, @"Invalid key received");
        }];
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
    
    NSLog(@"<> Finished processing versions");
    
    
    // ===================================================================================================
    // Verify if the indexProcessor actually did its job
    // ===================================================================================================
    //
    
    [self.storage refaultObjects:@[config]];
    
    XCTAssertEqualObjects(config.captainsLog, expectedLog,                  @"Invalid Log");
    XCTAssertEqualObjects(config.cost, expectedCost,                        @"Invalid Cost");
    XCTAssertEqualObjects(config.warpSpeed, expectedWarp,                   @"Invalid Warp");
    XCTAssertEqualObjects(config.ghost.version, endVersion,                 @"Invalid Ghost Version");
    XCTAssertTrue([self isGhostEqualToDictionary:data ghost:config.ghost],  @"Invalid Ghost MemberData");
}

- (void)testProcessVersionsWithExistingObjectsAndLocalPendingChangesFailsRebasingAndFavorsLocalData {
    
    // ===================================================================================================
	// Testing values!
    // ===================================================================================================
    //
    NSString *originalLog           = @"Original Captains Log";
    NSString *localPendingLog       = @"Local Captains Log";
    NSString *newRemoteLog          = @"Remote Captains Log";
    NSString *expectedLog           = localPendingLog;
    
    
    // ===================================================================================================
	// Helpers
    // ===================================================================================================
    //
    SPBucket* bucket = self.configBucket;
    
    
    // ===================================================================================================
	// Insert Config
    // ===================================================================================================
    //
    Config* config                  = [self.storage insertNewObjectForBucketName:bucket.name simperiumKey:nil];
    config.captainsLog              = originalLog;
    
    NSString* configSimperiumKey    = config.simperiumKey;
    
    
    // ===================================================================================================
    // Manually Intialize SPGhost: we're not relying on the backend to confirm these additions!
    // ===================================================================================================
    //
    NSMutableDictionary *memberData = [config.dictionary mutableCopy];
    SPGhost *ghost                  = [[SPGhost alloc] initWithKey:config.simperiumKey memberData:memberData];
    ghost.version                   = @"1";
    config.ghost                    = ghost;
    config.ghostData                = [memberData sp_JSONString];
    
	[self.storage save];
    
    NSLog(@"<> Successfully inserted Config object");
    
    
    // ===================================================================================================
    // Prepare Remote Entity Message
    // ===================================================================================================
    //
    NSString *endVersion    = [NSString stringWithFormat:@"%d", config.ghost.version.intValue + 1];
    
    NSDictionary *data      = @{
        NSStringFromSelector(@selector(captainsLog)) : newRemoteLog,
    };
    
    NSArray *versions       = @[ @[ config.simperiumKey, endVersion, data ] ];
    
    NSLog(@"<> Successfully generated versions");
    
    
    // ===================================================================================================
    // Add local pending changes
    // ===================================================================================================
    //
    config.captainsLog  = localPendingLog;
    
    [self.storage save];
    
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Index Processor Expectation"];
    
    dispatch_async(bucket.processorQueue, ^{
        
        [bucket.indexProcessor processVersions:versions bucket:bucket changeHandler:^(NSString *key) {
            XCTAssertEqualObjects(key, configSimperiumKey, @"Invalid key received");
        }];
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
    
    NSLog(@"<> Finished processing versions");
    
    
    // ===================================================================================================
    // Verify if the indexProcessor actually did its job
    // ===================================================================================================
    //

    [self.storage refaultObjects:@[config]];
    
    XCTAssertEqualObjects(config.captainsLog, expectedLog,                  @"Invalid Log");
    XCTAssertEqualObjects(config.ghost.version, endVersion,                 @"Invalid Ghost Version");
    XCTAssertTrue([self isGhostEqualToDictionary:data ghost:config.ghost],  @"Invalid Ghost MemberData");
}

- (void)testProcessVersionsWithExistingObjectsAndLocalPendingChangesWithRebaseDisabled {
    
    // ===================================================================================================
	// Testing values!
    // ===================================================================================================
    //
    NSString *originalLog           = @"Original Captains Log";
    NSString *localPendingLog       = @"Local Captains Log";
    NSString *newRemoteLog          = @"Remote Captains Log";
    NSString *expectedLog           = newRemoteLog;
    
    
    // ===================================================================================================
	// Helpers
    // ===================================================================================================
    //
	MockSimperium* s                = [MockSimperium mockSimperium];
	SPBucket* bucket                = [s bucketForName:NSStringFromClass([Config class])];
	id<SPStorageProvider> storage   = bucket.storage;
    
    
    // ===================================================================================================
	// Insert Config
    // ===================================================================================================
    //
    Config* config                  = [storage insertNewObjectForBucketName:bucket.name simperiumKey:nil];
    config.captainsLog              = originalLog;
    
    NSString* configSimperiumKey    = config.simperiumKey;
    
    // ===================================================================================================
    // Manually Intialize SPGhost: we're not relying on the backend to confirm these additions!
    // ===================================================================================================
    //
    NSMutableDictionary *memberData = [config.dictionary mutableCopy];
    SPGhost *ghost                  = [[SPGhost alloc] initWithKey:config.simperiumKey memberData:memberData];
    ghost.version                   = @"1";
    config.ghost                    = ghost;
    config.ghostData                = [memberData sp_JSONString];
    
	[storage save];
    
    NSLog(@"<> Successfully inserted Config object");
    
    
    // ===================================================================================================
    // Prepare Remote Entity Message
    // ===================================================================================================
    //
    NSString *endVersion    = [NSString stringWithFormat:@"%d", config.ghost.version.intValue + 1];
    
    NSDictionary *data      = @{
                                NSStringFromSelector(@selector(captainsLog)) : newRemoteLog,
                                };
    
    NSArray *versions       = @[ @[ config.simperiumKey, endVersion, data ] ];
    
    NSLog(@"<> Successfully generated versions");
    
    
    // ===================================================================================================
    // Add local pending changes
    // ===================================================================================================
    //
    config.captainsLog  = localPendingLog;
    
    [storage save];
    

    // ===================================================================================================
    // Disable Rebase
    // ===================================================================================================
    //
    dispatch_async(bucket.processorQueue, ^{
        [bucket.indexProcessor disableRebaseForObjectWithKey:configSimperiumKey];
    });
    
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Index Processor Expectation"];
    
    dispatch_async(bucket.processorQueue, ^{
        
        [bucket.indexProcessor processVersions:versions bucket:bucket changeHandler:^(NSString *key) {
            XCTAssertTrue(true, @"This should not get called");
        }];
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
    
    NSLog(@"<> Finished processing versions");
    
    
    // ===================================================================================================
    // Verify if the indexProcessor actually did its job
    // ===================================================================================================
    //
    
    [storage refaultObjects:@[config]];
    
    XCTAssertEqualObjects(config.captainsLog, expectedLog,                  @"Invalid Log");
    XCTAssertEqualObjects(config.ghost.version, endVersion,                 @"Invalid Ghost Version");
    XCTAssertTrue([self isGhostEqualToDictionary:data ghost:config.ghost],  @"Invalid Ghost MemberData");
}


#pragma mark - Helpers

- (BOOL)isGhostEqualToDictionary:(NSDictionary *)dictionary ghost:(SPGhost *)ghost {
    id dictionaryObject = nil;
    id ghostObject      = nil;
    
    for (id key in dictionary.allKeys) {
        dictionaryObject = dictionary[key];
        ghostObject      = ghost.memberData[key];
        
        if (![dictionaryObject isKindOfClass:[NSDate class]]) {
            return [dictionaryObject isEqual:ghostObject];
        }
        
        // Special treatment for NSDate: compare timeIntervals since 1970. isEqual fails randomly!
        return (((NSDate *)dictionaryObject).timeIntervalSince1970 == ((NSDate *)ghostObject).timeIntervalSince1970);

    }
    return true;
}

@end
