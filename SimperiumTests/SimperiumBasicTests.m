//
//  SimperiumBasicTests.m
//  SimperiumBasicTests
//
//  Created by Michael Johnston on 11-04-19.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SimperiumBasicTests.h"
#import "Config.h"
#import "Farm.h"
#import "SPBucket.h"
#import "DiffMatchPatch.h"

@implementation SimperiumBasicTests

- (void)testAuth
{
    NSLog(@"%@ start", self.name);
    STAssertTrue(token.length > 0, @"");
    NSLog(@"token is %@", token);
    NSLog(@"%@ end", self.name);
}

- (void)testAddingSingleObject
{
    NSLog(@"%@ start", self.name);
    [self createAndStartFarms];
    
    // Leader sends an object to followers
    Farm *leader = [farms objectAtIndex:0];
    [self connectFarms];
    
    NSNumber *refWarpSpeed = [NSNumber numberWithInt:2];
    SPBucket *leaderBucket = [leader.simperium bucketForName:@"Config"];
    leaderBucket.delegate = leader;
    leader.config = [leaderBucket insertNewObjectForKey:@"config"];
    [leader.config setValue:refWarpSpeed forKey:@"warpSpeed"];
    //leader.config.warpSpeed = refWarpSpeed;
    [leader.simperium save];
    [self expectAdditions:1 deletions:0 changes:0 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion], @"timed out");
//    STAssertTrue([leader.config.warpSpeed isEqualToNumber: refWarpSpeed], @"");
    STAssertTrue([[leader.config valueForKey:@"warpSpeed"] isEqualToNumber: refWarpSpeed], @"");
    
    // This is failing for the JSON case because the follower farms don't know what bucket to start listening
    // to. This can be worked around by adding a special prep method to farms. However they'll still fail because
    // I need to add dynamic schema support to the REMOTE ADD and REMOTE MODIFY cases as well, so that followers
    // can consruct their schemas as new data comes off the wire.
    
    [self ensureFarmsEqual:farms entityName:@"Config"];

    NSLog(@"%@ end", self.name); 
}

- (void)testDeletingSingleObject
{
    NSLog(@"%@ start", self.name);
    [self createAndStartFarms];

    // Leader sends an object to followers, then removes it
    Farm *leader = [farms objectAtIndex:0];
    [self connectFarms];
    
    SPBucket *bucket = [leader.simperium bucketForName:@"Config"];
    leader.config = [bucket insertNewObject];
    leader.config.simperiumKey = @"config";
    leader.config.warpSpeed = [NSNumber numberWithInt:2];
    [leader.simperium save];
    [self expectAdditions:1 deletions:0 changes:0 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion], @"timed out (adding)");
    
    [bucket deleteObject:leader.config];
    [leader.simperium save];
    [self expectAdditions:0 deletions:1 changes:0 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion], @"timed out (deleting)");
    
    int i=0;
    for (Farm *farm in farms) {
        farm.config = (Config *)[[farm.simperium bucketForName:@"Config"] objectForKey:@"config"];
        STAssertNil(farm.config, @"config %d wasn't deleted: %@", i, farm.config);
        i += 1;
    }
    NSLog(@"%@ end", self.name);    
}

- (void)testChangesToSingleObject
{
    NSLog(@"%@ start", self.name);
    [self createAndStartFarms];

    // Leader sends an object to followers, then changes multiple fields
    Farm *leader = [farms objectAtIndex:0];
    [self connectFarms];
    [self waitFor:1.0];
    
    leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    leader.config.simperiumKey = @"config";
    leader.config.warpSpeed = [NSNumber numberWithInt:2];
    leader.config.captainsLog = @"Hi";
    leader.config.shieldPercent = [NSNumber numberWithFloat:3.14];
    leader.config.cost = [NSDecimalNumber decimalNumberWithString:@"3.00"];
    [leader.simperium save];
    [self expectAdditions:1 deletions:0 changes:0 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion], @"timed out (adding)");
    STAssertNotNil(leader.config.ghostData, @"");

    NSNumber *refWarpSpeed = [NSNumber numberWithInt:4];
    NSString *refCaptainsLog = @"Hi!!!";
    NSNumber *refShieldPercent = [NSNumber numberWithFloat:2.718];
    NSDecimalNumber *refCost = [NSDecimalNumber decimalNumberWithString:@"4.00"];
    leader.config.warpSpeed = refWarpSpeed;
    leader.config.captainsLog = refCaptainsLog;
    leader.config.shieldPercent = refShieldPercent;
    leader.config.cost = refCost;
    [leader.simperium save];
    [self expectAdditions:0 deletions:0 changes:1 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion], @"timed out (changing)");
    
    STAssertTrue([refWarpSpeed isEqualToNumber: leader.config.warpSpeed], @"");
    STAssertTrue([refCaptainsLog isEqualToString: leader.config.captainsLog], @"");
    STAssertTrue([refShieldPercent isEqualToNumber: leader.config.shieldPercent], @"");
    STAssertTrue([refCost isEqualToNumber: leader.config.cost], @"");

    [self ensureFarmsEqual:farms entityName:@"Config"];
    NSLog(@"%@ end", self.name); 
}

- (void)testPendingChange
{
    NSLog(@"%@ start", self.name);
    [self createAndStartFarms];

    // Leader sends an object to followers, then changes multiple fields
    Farm *leader = [farms objectAtIndex:0];
    [self connectFarms];
    
    [self waitFor:1];
    
    leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    leader.config.simperiumKey = @"config";
    leader.config.warpSpeed = [NSNumber numberWithInt:2];
    leader.config.captainsLog = @"Hi";
    leader.config.shieldPercent = [NSNumber numberWithFloat:3.14];
    [leader.simperium save];
    [self expectAdditions:1 deletions:0 changes:0 fromLeader:leader expectAcks:YES];
    
    // Wait just enough time for the change to be sent, but not enough time for an ack to come back
    // (a better test will be to send a bunch of changes with random delays from 0..1s)
    [self waitFor:0.01];
    
    // Now change right away without waiting for the object insertion to be acked
    NSNumber *refWarpSpeed = [NSNumber numberWithInt:4];
    NSString *refCaptainsLog = @"Hi!!!";
    NSNumber *refShieldPercent = [NSNumber numberWithFloat:2.718];
    leader.config.warpSpeed = refWarpSpeed;
    leader.config.captainsLog = refCaptainsLog;
    leader.config.shieldPercent = refShieldPercent;
    [leader.simperium save];
    [self expectAdditions:0 deletions:0 changes:1 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion], @"timed out (changing)");
    
    STAssertTrue([refWarpSpeed isEqualToNumber: leader.config.warpSpeed], @"");
    STAssertTrue([refCaptainsLog isEqualToString: leader.config.captainsLog], @"");
    STAssertTrue([refShieldPercent isEqualToNumber: leader.config.shieldPercent], @"");
    [self ensureFarmsEqual:farms entityName:@"Config"];
    NSLog(@"%@ end", self.name);
}

@end
