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

#import "XCTestCase+Simperium.h"
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
    self.simperium      = [MockSimperium mockSimperium];
    self.storage        = _simperium.coreDataStorage;
    self.configBucket   = [_simperium bucketForName:NSStringFromClass([Config class])];
    
    // Make sure that we're not picking up old enqueued changes
    [self.configBucket.changeProcessor reset];
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
	// Insert Config
    // ===================================================================================================
    //
	for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
        NSString *originalLog           = [NSString sp_randomStringOfLength:SPRandomStringLength];
        
        // New post please!
		Config* config                  = [_storage insertNewObjectForBucketName:_configBucket.name simperiumKey:nil];
		config.captainsLog              = originalLog;
        
        // Manually Intialize SPGhost: we're not relying on the backend to confirm these additions!
        NSMutableDictionary *memberData = [config.dictionary mutableCopy];
        SPGhost *ghost                  = [[SPGhost alloc] initWithKey:config.simperiumKey memberData:memberData];
        ghost.version                   = @"1";
        config.ghost                    = ghost;
        config.ghostData                = [memberData sp_JSONString];
        
        // Keep a copy of the original title
        NSString *key                   = config.simperiumKey;
        originalLogs[key]               = originalLog;
        
        // And keep a reference to the post
		[configs addObject:config];
	}
    
	[_storage save];
    
    NSLog(@"<> Successfully inserted %d objects", (int)SPNumberOfEntities);
    
    
    // ===================================================================================================
    // Prepare Remote Changes
    // ===================================================================================================
    //
    for (Config *config in configs) {
        NSString *changeVersion     = [NSString sp_makeUUID];
        NSString *startVersion      = config.ghost.version;
        NSString *endVersion        = [NSString stringWithFormat:@"%d", startVersion.intValue + 1];
        NSString *delta             = @"An invalid delta here!";
        
        // Prepare the change itself
        NSDictionary *change    = @{
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
        
        changes[config.simperiumKey] = change;
    }
    
    NSLog(@"<> Successfully generated remote changes");
    
    
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
    
    NSLog(@"<> Finished processing remote changes");
    
    
    // ===================================================================================================
    // Verify if the changeProcessor actually did its job
    // ===================================================================================================
    //
    for (Config *config in configs) {
        NSDictionary *change    = changes[config.simperiumKey];
        NSString *endVersion    = change[CH_END_VERSION];
        NSString *originalTitle = originalLogs[config.simperiumKey];
        
        // THE check!
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
    
    NSMutableDictionary *memberData = [config.dictionary mutableCopy];
    SPGhost *ghost                  = [[SPGhost alloc] initWithKey:config.simperiumKey memberData:memberData];
    ghost.version                   = @"1";
    config.ghost                    = ghost;
    config.ghostData                = [memberData sp_JSONString];
    
    config.captainsLog              = localMemberData;
    
    [_simperium saveWithoutSyncing];
    
    NSLog(@"<> Config with invalid state successfully inserted");
    
    
    // ===================================================================================================
    // Prepare Remote Changes
    // ===================================================================================================
    //
    NSString *changeVersion         = [NSString sp_makeUUID];
    NSString *startVersion          = config.ghost.version;
    NSString *endVersion            = [NSString stringWithFormat:@"%d", startVersion.intValue + 1];
    
    // Prepare the change itself
    NSDictionary *change            = @{
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
    
    changes[config.simperiumKey] = change;
    
    NSLog(@"<> Successfully generated remote changes");
    
    
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
    
    NSLog(@"<> Finished processing remote changes");
    
    
    // ===================================================================================================
    // Verify
    // ===================================================================================================
    //
    
    // Reload the Object
    [_storage refaultObjects:@[config]];
    
    // We expect the error handling code to detect the inconsistency, and fall back to remote data
    
    // TODO:
    // Implement a recovery mechanism
    XCTAssertNotEqual(config.captainsLog, remoteMemberData, @"Inconsistency detected");
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

@end
