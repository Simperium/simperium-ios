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

- (void)testReindex
{
    NSLog(@"%@ start", self.name);
    // Leader sends an object to a follower, follower goes offline, both make changes, follower reconnects
    Farm *leader = [self createFarm:@"leader"];
    Farm *follower = [self createFarm:@"follower"];
    [leader start];
    [follower start];
    
    NSArray *farmArray = [NSArray arrayWithObjects:leader, follower, nil];
    [leader connect];
    [follower connect];
    [self waitFor:1.0];
    
    // Add one object
    leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    leader.config.simperiumKey = @"config";
    leader.config.captainsLog = @"1";
    [leader.simperium save];
    leader.expectedAcknowledgments = 1;
    follower.expectedAdditions = 1;
    STAssertTrue([self waitForCompletion: 4.0 farmArray:farmArray], @"timed out (adding one)");
    [self resetExpectations: farmArray];
    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    NSLog(@"****************************DISCONNECT*************************");
    [follower disconnect];

    // Add 50 objects to push the cv off the back of the queue (max 50 versions)
    int numConfigs = 50;
    NSLog(@"****************************ADD*************************");
    for (int i=0; i<numConfigs; i++) {
        Config *config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
        config.warpSpeed = [NSNumber numberWithInt:2];
        config.captainsLog = @"Hi";
        config.shieldPercent = [NSNumber numberWithFloat:3.14];
    }
    [leader.simperium save];
    [self expectAdditions:numConfigs deletions:0 changes:0 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion: numConfigs/3.0 farmArray:farmArray], @"timed out (adding many)");
    
    NSLog(@"****************************RECONNECT*************************");
    [self resetExpectations:farmArray];
    [follower connect];
    
    // Expect 404 and reindex?
    follower.expectedAdditions = numConfigs;
    STAssertTrue([self waitForCompletion:numConfigs/3.0 farmArray:farmArray], @"timed out (receiving many)");
    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    
    NSLog(@"%@ end", self.name);
}


@end
