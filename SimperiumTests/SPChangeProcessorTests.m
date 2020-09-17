//
//  SPChangeProcessorTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 6/10/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MockSimperium.h"
#import "Simperium+Internals.h"
#import "SPBucket+Internals.h"

#import "SPManagedObject+Mock.h"
#import "SPCoreDataStorage+Mock.h"

#import "SPGhost.h"
#import "SPChangeProcessor.h"
#import "SPCoreDataStorage.h"
#import "Config.h"

#import "NSString+Simperium.h"
#import "JSONKit+Simperium.h"
#import "DiffMatchPatch.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSInteger const SPNumberOfEntities           = 100;
static NSString * const SPRemoteClientID            = @"OSX-Remote!";
static NSUInteger const SPRandomStringLength        = 1000;
static NSTimeInterval const SPExpectationTimeout    = 60.0;


#pragma mark ====================================================================================
#pragma mark SPChangeProcessorTests
#pragma mark ====================================================================================

@interface SPChangeProcessorTests : XCTestCase
@property (nonatomic, strong) Simperium*            simperium;
@property (nonatomic, strong) SPCoreDataStorage*    storage;
@property (nonatomic, strong) SPBucket*             configBucket;
@end

@implementation SPChangeProcessorTests

- (void)setUp {
    [super setUp];

    self.simperium      = [MockSimperium mockSimperium];
    self.storage        = _simperium.coreDataStorage;
    self.configBucket   = [_simperium bucketForName:NSStringFromClass([Config class])];
    
    // Make sure that we're not picking up old enqueued changes
    [self.configBucket.changeProcessor reset];
}

- (void)tearDown {
    [super tearDown];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Signout Expectation"];

    [self.simperium signOutAndRemoveLocalData:false completion:^{
        [expectation fulfill];
    }];

    NSLog(@"Logged Out");
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:nil];
}

- (void)testProcessRemoteChangeWithInvalidDelta {
    
    // ===================================================================================================
	// Helpers
    // ===================================================================================================
    //
    NSMutableArray* configs             = [NSMutableArray array];
    NSMutableDictionary *changes        = [NSMutableDictionary dictionary];
    NSMutableDictionary *originalLogs   = [NSMutableDictionary dictionary];
    
    // ===================================================================================================
    // Insert SPNumberOfEntities Configs
    // ===================================================================================================
    //
	for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
        // New Config!
		Config* config                      = [_storage insertNewObjectForBucketName:_configBucket.name simperiumKey:nil];
		config.captainsLog                  = [NSString sp_randomStringOfLength:SPRandomStringLength];
        [config test_simulateGhostData];

        // Keep a copy of the original title
        originalLogs[config.simperiumKey]   = config.captainsLog;
        
        // And keep a reference to the post
		[configs addObject:config];
	}
    
    [self.storage save];
    [self.storage test_waitUntilSaveCompletes];

    // ===================================================================================================
    // Prepare Remote Changes
    // ===================================================================================================
    //
    for (Config *config in configs) {
        NSString *changeVersion         = [NSString sp_makeUUID];
        NSString *startVersion          = config.ghost.version;
        NSString *endVersion            = [NSString stringWithFormat:@"%d", startVersion.intValue + 1];
        NSString *delta                 = @"An invalid delta here!";
        
        changes[config.simperiumKey]    = @{
                                            CH_CLIENT_ID        : SPRemoteClientID,
                                            CH_CHANGE_VERSION   : changeVersion,
                                            CH_START_VERSION    : startVersion,
                                            CH_END_VERSION      : endVersion,
                                            CH_KEY              : config.simperiumKey,
                                            CH_OPERATION        : CH_MODIFY,
                                            CH_VALUE            : @{
                                                    NSStringFromSelector(@selector(captainsLog))    : @{
                                                            CH_OPERATION    : CH_DATA,
                                                            CH_VALUE        : delta
                                                    }
                                                }
                                        };
    }
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Process Expectation"];
    
    dispatch_async(_configBucket.processorQueue, ^{
        __block NSInteger errorCount = 0;
        [_configBucket.changeProcessor processRemoteChanges:changes.allValues
                                                     bucket:_configBucket
                                             successHandler:^(NSString *simperiumKey, NSString *version) {
                                                 XCTAssertFalse(true, @"This should not get executed");
                                             }
                                               errorHandler:^(NSString *simperiumKey, NSString *version, NSError *error) {
                                                   XCTAssertTrue(error.code == SPProcessorErrorsReceivedInvalidChange, @"Invalid error code");
                                                   ++errorCount;
                                               }];
        
        XCTAssertTrue(errorCount == changes.count, @"Missed an error?");
        [expectation fulfill];
    });
    

    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
    
    
    // ===================================================================================================
    // Verify if the changeProcessor actually did its job
    // ===================================================================================================
    //
    for (Config *config in configs) {
        NSDictionary *change    = changes[config.simperiumKey];
        NSString *endVersion    = change[CH_END_VERSION];
        NSString *originalTitle = originalLogs[config.simperiumKey];
        
        XCTAssertEqualObjects(config.captainsLog, originalTitle,    @"Invalid CaptainsLog");
        XCTAssertFalse([config.ghost.version isEqual:endVersion],   @"Invalid Ghost Version");
    }
}


- (void)testProcessRemoteChangeWithLocalInconsistentState {
    
    // ===================================================================================================
    // Helpers
    // ===================================================================================================
    //
    DiffMatchPatch *dmp             = [DiffMatchPatch new];
    NSMutableDictionary *changes    = [NSMutableDictionary dictionary];

    // Note:
    // Force an Inconsistent State == "Ghost != Member Data" because, for X reason, a remote delta wasn't applied
    // This particular inconsistency will neutralize new changes coming through. We expect the changeProcessor to
    // detect this, and fall back to ghost data.
    //
    NSString *remoteMemberData		= @"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX NEW NEW";
    NSString *localGhostData        = @"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n";
    NSString *localMemberData       = @"";
    NSMutableArray *rawDiff         = [dmp diff_mainOfOldString:localGhostData andNewString:remoteMemberData];
    NSString *delta                 = [dmp diff_toDelta:rawDiff];

    
    // ===================================================================================================
    // Insert Config
    // ===================================================================================================
    //
    Config* config                  = [_storage insertNewObjectForBucketName:_configBucket.name simperiumKey:nil];
    config.captainsLog              = localGhostData;
    [config test_simulateGhostData];
    
    config.captainsLog              = localMemberData;
    
    [_simperium saveWithoutSyncing];
    [_storage test_waitUntilSaveCompletes];
    
    
    // ===================================================================================================
    // Prepare Remote Changes
    // ===================================================================================================
    //
    NSString *changeVersion         = [NSString sp_makeUUID];
    NSString *startVersion          = config.ghost.version;
    NSString *endVersion            = [NSString stringWithFormat:@"%d", startVersion.intValue + 1];
    
    // Prepare the change itself
    changes[config.simperiumKey]    = @{
                                        CH_CLIENT_ID        : SPRemoteClientID,
                                        CH_CHANGE_VERSION   : changeVersion,
                                        CH_START_VERSION    : startVersion,
                                        CH_END_VERSION      : endVersion,
                                        CH_KEY              : config.simperiumKey,
                                        CH_OPERATION        : CH_MODIFY,
                                        CH_VALUE            : @{
                                                NSStringFromSelector(@selector(captainsLog))    : @{
                                                        CH_OPERATION    : CH_DATA,
                                                        CH_VALUE        : delta
                                                        }
                                                }
                                    };
    
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Process Expectation"];
    
    dispatch_async(_configBucket.processorQueue, ^{
        [_configBucket.changeProcessor processRemoteChanges:changes.allValues
                                                     bucket:_configBucket
                                             successHandler:^(NSString *simperiumKey, NSString *version) { }
                                               errorHandler:^(NSString *simperiumKey, NSString *version, NSError *error) {
                                                   XCTAssertFalse(true, @"This should not get executed");
                                               }];
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
    
    // ===================================================================================================
    // Verify
    // ===================================================================================================
    //
    
    // Reload the Object
    [_storage refaultObjects:@[config]];
    
    // We expect the error handling code to detect the inconsistency, and fall back to remote data
    XCTAssertNotEqual(config.captainsLog, remoteMemberData, @"Inconsistency detected");
}

- (void)testProcessRemoteChangeWithLocalPendingChange {
    
    // ===================================================================================================
    // Helpers
    // ===================================================================================================
    //
    DiffMatchPatch *dmp             = [DiffMatchPatch new];
    NSMutableDictionary *changes    = [NSMutableDictionary dictionary];
    
    // Note:
    // Force an Inconsistent State == "Ghost != Member Data" because, for X reason, a remote delta wasn't applied
    // This particular inconsistency will neutralize new changes coming through. We expect the changeProcessor to
    // detect this, and fall back to ghost data.
    //
    NSString *remoteMemberData		= @"Line 1\nLine 2\n";
    NSString *localGhostData        = @"Line 1\n";
    NSString *localMemberData       = @"Line 1\nLine 3";
    NSString *expectedMemberData    = @"Line 1\nLine 2\nLine 3";
    NSMutableArray *rawDiff         = [dmp diff_mainOfOldString:localGhostData andNewString:remoteMemberData];
    NSString *delta                 = [dmp diff_toDelta:rawDiff];
    
    
    // ===================================================================================================
    // Insert Config
    // ===================================================================================================
    //
    Config* config                  = [_storage insertNewObjectForBucketName:_configBucket.name simperiumKey:nil];
    config.captainsLog              = localGhostData;
    [config test_simulateGhostData];
    
    config.captainsLog              = localMemberData;
    
    [_simperium saveWithoutSyncing];
    [_storage test_waitUntilSaveCompletes];
    
    
    // ===================================================================================================
    // Prepare Remote Changes
    // ===================================================================================================
    //
    NSString *changeVersion         = [NSString sp_makeUUID];
    NSString *startVersion          = config.ghost.version;
    NSString *endVersion            = [NSString stringWithFormat:@"%d", startVersion.intValue + 1];
    
    // Prepare the change itself
    changes[config.simperiumKey]    = @{
                                        CH_CLIENT_ID        : SPRemoteClientID,
                                        CH_CHANGE_VERSION   : changeVersion,
                                        CH_START_VERSION    : startVersion,
                                        CH_END_VERSION      : endVersion,
                                        CH_KEY              : config.simperiumKey,
                                        CH_OPERATION        : CH_MODIFY,
                                        CH_VALUE            : @{
                                                NSStringFromSelector(@selector(captainsLog))    : @{
                                                        CH_OPERATION    : CH_DATA,
                                                        CH_VALUE        : delta
                                                        }
                                                }
                                        };
    
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Process Expectation"];
    
    dispatch_async(_configBucket.processorQueue, ^{
        [_configBucket.changeProcessor processRemoteChanges:changes.allValues
                                                     bucket:_configBucket
                                             successHandler:^(NSString *simperiumKey, NSString *version) { }
                                               errorHandler:^(NSString *simperiumKey, NSString *version, NSError *error) {
                                                   XCTAssertFalse(true, @"This should not get executed");
                                               }];
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
    
    // ===================================================================================================
    // Verify
    // ===================================================================================================
    //
    
    // Reload the Object
    [_storage refaultObjects:@[config]];
    
    // We expect the error handling code to detect the inconsistency, and fall back to remote data
    XCTAssertNotEqual(config.captainsLog, expectedMemberData, @"Inconsistency detected");
}

- (void)testEnumeratePendingChanges {
    
    // ===================================================================================================
    // Insert SPNumberOfEntities Configs
    // ===================================================================================================
    //
    SPChangeProcessor *processor        = self.configBucket.changeProcessor;
    NSMutableSet *keys                  = [NSMutableSet set];
    
    for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
        Config* config                  = [_storage insertNewObjectForBucketName:_configBucket.name simperiumKey:nil];
        config.captainsLog              = [NSString sp_randomStringOfLength:SPRandomStringLength];
        [keys addObject:config.simperiumKey];
    }
    
    [self.storage save];
    [self.storage test_waitUntilSaveCompletes];
    
    // ===================================================================================================
    // Process the changes
    // ===================================================================================================
    //
    dispatch_async(self.configBucket.processorQueue, ^{
        [self.configBucket.changeProcessor processLocalObjectsWithKeys:keys bucket:_configBucket];
    });
    
    // ===================================================================================================
    // Enumerate Pending Changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation      = [self expectationWithDescription:@"Process Expectation"];
    
    dispatch_async(self.configBucket.processorQueue, ^{
        [processor enumeratePendingChangesForBucket:self.configBucket block:^(NSDictionary *change) {
            NSString *simperiumKey = change[CH_KEY];
            [keys removeObject:simperiumKey];
            
            if (keys.count == 0) {
                [expectation fulfill];
            }
        }];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
}

- (void)testEnumerateQueuedDeletions {
    
    // ===================================================================================================
    // Enqueue SPNumberOfEntities Deletions
    // ===================================================================================================
    //
    SPChangeProcessor *processor    = self.configBucket.changeProcessor;
    
    NSMutableSet *keys              = [NSMutableSet set];
    
    for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
        NSString *simperiumKey = [NSString sp_makeUUID];
        [processor enqueueObjectForDeletion:simperiumKey bucket:_configBucket];
        [keys addObject:simperiumKey];
    }
    
    // ===================================================================================================
    // Verify the Enqueued Deletions
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Process Expectation"];

    [processor enumerateQueuedDeletionsForBucket:self.configBucket block:^(NSDictionary *change) {
        NSString *simperiumKey = change[CH_KEY];
        [keys removeObject:simperiumKey];
        
        if (keys.count == 0) {
            [expectation fulfill];
        }
    }];

    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
}

- (void)testEnumerateQueuedChanges {
    
    // ===================================================================================================
    // Insert SPNumberOfEntities Configs
    // ===================================================================================================
    //
    SPChangeProcessor *processor        = self.configBucket.changeProcessor;
    NSMutableSet *keys                  = [NSMutableSet set];
    
    for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
        Config* config                  = [_storage insertNewObjectForBucketName:_configBucket.name simperiumKey:nil];
        config.captainsLog              = [NSString sp_randomStringOfLength:SPRandomStringLength];
        
        [processor enqueueObjectForMoreChanges:config.simperiumKey bucket:_configBucket];
        [keys addObject:config.simperiumKey];
    }
    
    [_storage save];
    [self.storage test_waitUntilSaveCompletes];

    // ===================================================================================================
    // Verify the Enqueued Changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation      = [self expectationWithDescription:@"Process Expectation"];
    
    dispatch_async(self.configBucket.processorQueue, ^{
        [processor enumerateQueuedChangesForBucket:self.configBucket block:^(NSDictionary *change) {
            NSString *simperiumKey = change[CH_KEY];
            [keys removeObject:simperiumKey];
            
            if (keys.count == 0) {
                [expectation fulfill];
            }
        }];
    });
    
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
}

- (void)testEnumerateRetryChangesWithoutOverridingRemoteData {
    
    // ===================================================================================================
    // Insert SPNumberOfEntities Configs
    // ===================================================================================================
    //
    SPChangeProcessor *processor        = self.configBucket.changeProcessor;
    NSMutableSet *keys                  = [NSMutableSet set];
    
    for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
        Config* config                  = [_storage insertNewObjectForBucketName:_configBucket.name simperiumKey:nil];
        config.captainsLog              = [NSString sp_randomStringOfLength:SPRandomStringLength];
        [keys addObject:config.simperiumKey];
    }
    
    [_storage save];
    [_storage test_waitUntilSaveCompletes];

    // ===================================================================================================
    // Generate Changesets
    // ===================================================================================================
    //
    dispatch_async(self.configBucket.processorQueue, ^{
        [processor processLocalObjectsWithKeys:keys bucket:_configBucket];
    });
    
    // ===================================================================================================
    // Enqueue for Retry
    // ===================================================================================================
    //
    dispatch_async(self.configBucket.processorQueue, ^{
        for (NSString *simperiumKey in keys) {
            [processor enqueueObjectForRetry:simperiumKey bucket:_configBucket overrideRemoteData:false];
        }
    });
    
    // ===================================================================================================
    // Verify the Enqueued Retries
    // ===================================================================================================
    //
    XCTestExpectation *expectation      = [self expectationWithDescription:@"Process Expectation"];
    
    dispatch_async(self.configBucket.processorQueue, ^{
        [processor enumerateRetryChangesForBucket:self.configBucket block:^(NSDictionary *change) {
            NSDictionary *fullData = change[CH_DATA];
            XCTAssertNil(fullData, @"The changeset should not carry the full data");
            
            NSString *simperiumKey = change[CH_KEY];
            [keys removeObject:simperiumKey];
            
            if (keys.count == 0) {
                [expectation fulfill];
            }
        }];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
}

- (void)testEnumerateRetryChangesOverridingRemoteData {
    
    // ===================================================================================================
    // Insert SPNumberOfEntities Configs
    // ===================================================================================================
    //
    SPChangeProcessor *processor        = self.configBucket.changeProcessor;
    NSMutableSet *keys                  = [NSMutableSet set];
    
    for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
        Config* config                  = [_storage insertNewObjectForBucketName:_configBucket.name simperiumKey:nil];
        config.captainsLog              = [NSString sp_randomStringOfLength:SPRandomStringLength];
        [keys addObject:config.simperiumKey];
    }
    
    [_storage save];
    [_storage test_waitUntilSaveCompletes];
    
    // ===================================================================================================
    // Enqueue the objects for Retry
    // ===================================================================================================
    //
    dispatch_async(self.configBucket.processorQueue, ^{
        for (NSString *simperiumKey in keys) {
            [processor enqueueObjectForRetry:simperiumKey bucket:_configBucket overrideRemoteData:true];
        }
    });
    
    // ===================================================================================================
    // Enumerate objects for Retry
    // ===================================================================================================
    //
    XCTestExpectation *expectation      = [self expectationWithDescription:@"Process Expectation"];
    
    dispatch_async(self.configBucket.processorQueue, ^{
        [processor enumerateRetryChangesForBucket:self.configBucket block:^(NSDictionary *change) {
            NSDictionary *fullData = change[CH_DATA];
            XCTAssertNotNil(fullData, @"The changeset should not carry the full data");
            
            NSString *simperiumKey = change[CH_KEY];
            [keys removeObject:simperiumKey];
            
            if (keys.count == 0) {
                [expectation fulfill];
            }
        }];
    });
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
}

- (void)testInvalidDeltaCausesGhostIntegrityError {

    // ===================================================================================================
    // Payload
    // ===================================================================================================
    //
    NSString *localGhostData        = @"☺️🖖🏿";
    NSString *localMemberData       = @"☺️😃🖖🏿";
    NSString *delta                 = @"=3\t+(null)\t=3";


    // ===================================================================================================
    // Insert Config
    // ===================================================================================================
    //
    Config* config                  = [_storage insertNewObjectForBucketName:_configBucket.name simperiumKey:nil];
    config.captainsLog              = localGhostData;
    [config test_simulateGhostData];

    config.captainsLog              = localMemberData;

    [_simperium saveWithoutSyncing];
    [_storage test_waitUntilSaveCompletes];


    // ===================================================================================================
    // Prepare Remote Changes
    // ===================================================================================================
    //
    NSMutableDictionary *changes    = [NSMutableDictionary dictionary];
    NSString *changeVersion         = [NSString sp_makeUUID];
    NSString *startVersion          = config.ghost.version;
    NSString *endVersion            = [NSString stringWithFormat:@"%d", startVersion.intValue + 1];

    // Prepare the change itself
    changes[config.simperiumKey]    = @{
                                        CH_CLIENT_ID        : SPRemoteClientID,
                                        CH_CHANGE_VERSION   : changeVersion,
                                        CH_START_VERSION    : startVersion,
                                        CH_END_VERSION      : endVersion,
                                        CH_KEY              : config.simperiumKey,
                                        CH_OPERATION        : CH_MODIFY,
                                        CH_VALUE            : @{
                                                NSStringFromSelector(@selector(captainsLog))    : @{
                                                        CH_OPERATION    : CH_DATA,
                                                        CH_VALUE        : delta
                                                        }
                                                }
                                    };


    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
    XCTestExpectation *expectation = [self expectationWithDescription:@"Process Expectation"];

    dispatch_async(_configBucket.processorQueue, ^{
        [_configBucket.changeProcessor processRemoteChanges:changes.allValues
                                                     bucket:_configBucket
                                             successHandler:^(NSString *simperiumKey, NSString *version) {
                                                    XCTFail(@"We're expecting an actual error here!");
                                                }
                                               errorHandler:^(NSString *simperiumKey, NSString *version, NSError *error) {
                                                    XCTAssert(error.code == SPProcessorErrorsEntityGhostIntegrity, @"We're expecting an Integrity Error");
                                                }];

        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
}

@end
