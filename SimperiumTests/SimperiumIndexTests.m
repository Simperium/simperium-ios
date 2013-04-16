//
//  SimperiumIndexTests.m
//  SimperiumIndexTests
//
//  Created by Michael Johnston on 11-04-19.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SimperiumIndexTests.h"
#import "Config.h"
#import "Farm.h"
#import "SPBucket.h"
#import "DiffMatchPatch.h"

@implementation SimperiumIndexTests

- (void)testIndex
{
    NSLog(@"%@ start", self.name);
    [self createAndStartFarms];

    // Leader sends an object to followers, but make followers get it from the index
    Farm *leader = [farms objectAtIndex:0];
    [leader connect];
    [self waitFor:1.0];
    
    NSNumber *refWarpSpeed = [NSNumber numberWithInt:2];
    leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    leader.config.simperiumKey = @"config";
    leader.config.warpSpeed = refWarpSpeed;
    [leader.simperium save];
    leader.expectedAcknowledgments = 1;
    STAssertTrue([self waitForCompletion], @"timed out");
    
    // Make a change to ensure version numbers increase
    refWarpSpeed = [NSNumber numberWithInt:4];
    NSString *refCaptainsLog = @"Hi!!!";
    NSNumber *refShieldPercent = [NSNumber numberWithFloat:2.718];
    leader.config.warpSpeed = refWarpSpeed;
    leader.config.captainsLog = refCaptainsLog;
    leader.config.shieldPercent = refShieldPercent;
    [leader.simperium save];
    leader.expectedAcknowledgments = 1;
    STAssertTrue([self waitForCompletion], @"timed out (changing)");

    // The object was synced, now connect with the followers
    for (Farm *farm in farms) {
        if (farm == leader)
            continue;
        [farm connect];
    }
    [self resetExpectations: farms];
    [self expectAdditions:1 deletions:0 changes:0 fromLeader:leader expectAcks:NO];
    
    STAssertTrue([self waitForCompletion], @"timed out");
    
    [self ensureFarmsEqual:farms entityName:@"Config"];
    NSLog(@"%@ end", self.name);     
}

- (void)testLargerIndex
{
    NSLog(@"%@ start", self.name);
    [self createAndStartFarms];

    // Leader sends an object to followers, but make followers get it from the index
    Farm *leader = [farms objectAtIndex:0];
    [leader connect];
    [self waitFor:5.0];
    
    NSNumber *refWarpSpeed = [NSNumber numberWithInt:2];
    int numObjects = 2;
    for (int i=0; i<numObjects; i++) {
        leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
        leader.config.warpSpeed = refWarpSpeed;
    }
    [leader.simperium save];
    leader.expectedAcknowledgments = numObjects;
    STAssertTrue([self waitForCompletion], @"timed out");
    
    // The object was synced, now connect with the followers
    for (Farm *farm in farms) {
        if (farm == leader)
            continue;
        [farm connect];
    }
    [self resetExpectations: farms];
    [self expectAdditions:numObjects deletions:0 changes:0 fromLeader:leader expectAcks:NO];
    
    STAssertTrue([self waitForCompletion], @"timed out");
    
    [self ensureFarmsEqual:farms entityName:@"Config"];
    NSLog(@"%@ end", self.name);    
}


@end
