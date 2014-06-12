//
//  SPChangeProcessorTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 6/10/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Simperium.h"
#import "MockSimperium.h"
#import "SPBucket+Internals.h"
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

static NSInteger const SPNumberOfEntities       = 100;
static NSString * const SPRemoteClientID        = @"OSX-Remote!";
static NSUInteger const SPRandomStringLength    = 1000;


#pragma mark ====================================================================================
#pragma mark SPChangeProcessorTests
#pragma mark ====================================================================================

@interface SPChangeProcessorTests : XCTestCase

@end

@implementation SPChangeProcessorTests

- (void)testApplyRemoteDiffWithLocalChanges
{
    // ===================================================================================================
	// Helpers
    // ===================================================================================================
    //
	MockSimperium* s                    = [MockSimperium mockSimperium];
	SPBucket* bucket                    = [s bucketForName:NSStringFromClass([Config class])];
	SPCoreDataStorage* storage          = bucket.storage;
	NSMutableArray* configs             = [NSMutableArray array];
    DiffMatchPatch *dmp                 = [[DiffMatchPatch alloc] init];
    NSMutableDictionary *changes        = [NSMutableDictionary dictionary];
    NSMutableDictionary *originalLogs   = [NSMutableDictionary dictionary];
    NSString *remoteLogFormat           = @"REMOTE PREPEND\n%@\nREMOTE APPEND";
    NSString *localLogFormat            = @"LOCAL  PREPEND\n%@\nLOCAL  APPEND";
    NSNumber *localWarp                 = @(10);
    NSNumber *remoteWarp                = @(31337);
    
    
    // ===================================================================================================
	// Insert Posts
    // ===================================================================================================
    //
	for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
        NSString *originalLog           = [NSString sp_randomStringOfLength:SPRandomStringLength];
        
        // New post please!
		Config* config                  = [storage insertNewObjectForBucketName:bucket.name simperiumKey:nil];
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

	[storage save];
    
    NSLog(@"<> Successfully inserted %d objects", (int)SPNumberOfEntities);
    
    
    // ===================================================================================================
    // Prepare Remote Changes
    // ===================================================================================================
    //
    for (Config *config in configs) {
        NSString *changeVersion     = [NSString sp_makeUUID];
        NSString *startVersion      = config.ghost.version;
        NSString *endVersion        = [NSString stringWithFormat:@"%d", startVersion.intValue + 1];
        NSString *newTitle          = [NSString stringWithFormat:remoteLogFormat, config.captainsLog];
        
        // Calculate the delta between the old and nu title's
        NSMutableArray *diffList    = [dmp diff_mainOfOldString:config.captainsLog andNewString:newTitle];
        if (diffList.count > 2) {
            [dmp diff_cleanupSemantic:diffList];
            [dmp diff_cleanupEfficiency:diffList];
        }
    
        // Construct the patch delta and return it as a change operation
        NSString *delta = [dmp diff_toDelta:diffList];
        
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
                                                                                            },
                                        NSStringFromSelector(@selector(warpSpeed))      : @{
                                                                                                CH_OPERATION    : CH_DATA,
                                                                                                CH_VALUE        : remoteWarp
                                                                                            }
                                    }
        };
        
        changes[config.simperiumKey] = change;
    }
    
    NSLog(@"<> Successfully generated remote changes");
    

    // ===================================================================================================
    // Perform Local Changes (And store them!)
    // ===================================================================================================
    //
    for (Config *config in configs) {
        config.captainsLog = [NSString stringWithFormat:localLogFormat, config.captainsLog];
    }

    [storage save];
    
    NSLog(@"<> Successfully performed local changes");
    

    // ===================================================================================================
    // Perform Local Changes on a second property. Don't save them:
    //      We expect unsaved values not to get overwritten by remote delta's!
    // ===================================================================================================
    //
    for (Config *config in configs) {
        config.warpSpeed = localWarp;
    }
    
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
	StartBlock();
    
    dispatch_async(bucket.processorQueue, ^{
        [bucket.changeProcessor processRemoteChanges:changes.allValues
                                              bucket:bucket
                                        errorHandler:^(NSString *simperiumKey, NSError *error) {
                                            
                                        }];
        
		dispatch_async(dispatch_get_main_queue(), ^{
			EndBlock();
		});
    });
    
	WaitUntilBlockCompletes();
    
    NSLog(@"<> Finished processing remote changes");
    
    
    // ===================================================================================================
    // Verify if the changeProcessor actually did its job
    // ===================================================================================================
    //
    for (Config *config in configs) {
        NSDictionary *change    = changes[config.simperiumKey];
        NSString *endVersion    = change[CH_END_VERSION];
        
        // Rebuild the expected Post Title
        NSString *originalTitle = originalLogs[config.simperiumKey];
        NSString *expectedTitle = [NSString stringWithFormat:localLogFormat, originalTitle];
        expectedTitle           = [NSString stringWithFormat:remoteLogFormat, expectedTitle];
        
        // THE check!
        XCTAssert([config.warpSpeed isEqualToNumber:localWarp], @"Invalid warp value");
        XCTAssert([config.captainsLog isEqualToString:expectedTitle], @"Invalid Post Title");
        XCTAssert([config.ghost.version isEqual:endVersion], @"Invalid Ghost Version");
    }
}

@end
