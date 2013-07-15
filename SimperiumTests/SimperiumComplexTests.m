//
//  SimperiumComplexTests.m
//  SimperiumComplexTests
//
//  Created by Michael Johnston on 11-04-19.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SimperiumComplexTests.h"
#import "Config.h"
#import "Farm.h"
#import "SPBucket.h"
#import "DiffMatchPatch.h"

@implementation SimperiumComplexTests

- (void)testChangesToMultipleObjects
{
    NSLog(@"%@ start", self.name);
    [self createAndStartFarms];

    NSUInteger numConfigs = NUM_MULTIPLE_CONFIGS;
    
    // Leader sends an object to followers, then changes multiple fields
    Farm *leader = [farms objectAtIndex:0];
    [self connectFarms];
    
    
    NSLog(@"****************************ADD*************************");
    for (int i=0; i<numConfigs; i++) {
        Config *config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
        config.warpSpeed = [NSNumber numberWithInt:2];
        config.captainsLog = @"Hi";
        config.shieldPercent = [NSNumber numberWithFloat:3.14];
    }    
    [leader.simperium save];
    [self expectAdditions:numConfigs deletions:0 changes:0 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion: numConfigs*8 farmArray:farms], @"timed out (adding)");
    [self ensureFarmsEqual:farms entityName:@"Config"];
    
    NSLog(@"****************************CHANGE*************************");
    NSArray *leaderConfigs = [[leader.simperium bucketForName:@"Config"] allObjects];
    STAssertEquals(numConfigs, [leaderConfigs count], @"");
    for (int i=0; i<numConfigs; i++) {
        Config *config = [leaderConfigs objectAtIndex:i];
        config.warpSpeed = [NSNumber numberWithInt:4];
        config.captainsLog = @"Hi!!!";
        config.shieldPercent = [NSNumber numberWithFloat:2.718];
    }
    [leader.simperium save];
    [self expectAdditions:0 deletions:0 changes:numConfigs fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion: numConfigs*NUM_FARMS*8 farmArray:farms], @"timed out (changing)");
    
    // Make sure the change worked
    Config *leaderConfig = [leaderConfigs objectAtIndex:0];
    STAssertTrue([leaderConfig.captainsLog isEqualToString: @"Hi!!!"], @"");
    
    [self ensureFarmsEqual:farms entityName:@"Config"];
    
    NSLog(@"%@ end", self.name); 
}


- (void)testMultiplePendingChanges
{
    NSLog(@"%@ start", self.name);
    [self createAndStartFarms];
    
    // Leader sends objects to followers, then changes multiple fields
    Farm *leader = [farms objectAtIndex:0];
    [self connectFarms];
    
    [self waitFor:1];
    
    leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    leader.config.simperiumKey = @"config";
    leader.config.warpSpeed = [NSNumber numberWithInt:2];
    leader.config.captainsLog = @"Hi";
    leader.config.shieldPercent = [NSNumber numberWithFloat:3.14];
    
    Config *config2 = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    config2.simperiumKey = @"config2";
    config2.captainsLog = @"The second";
    
    [leader.simperium save];
    
    // The timing here is critical for testing websockets...it needs to be long enough for the first save to be processed and sent, but not
    // so long that the ack has been processed. Find a way to block for successful sends instead.
    // NOTE: This test will fail sometimes as a result of this imprecise timing.
    [self waitFor:0.1];
    
    //[self expectAdditions:2 deletions:0 changes:0 fromLeader:leader expectAcks:YES];
        
    // Now change right away without waiting for the object insertion to be acked
    NSNumber *refWarpSpeed = [NSNumber numberWithInt:4];
    NSString *refCaptainsLog = @"Hi!!!";
    NSNumber *refShieldPercent = [NSNumber numberWithFloat:2.718];
    leader.config.warpSpeed = refWarpSpeed;
    leader.config.captainsLog = refCaptainsLog;
    leader.config.shieldPercent = refShieldPercent;
    
    config2.captainsLog = @"The second (edited)";
    
    [leader.simperium save];
    
    [self expectAdditions:2 deletions:0 changes:2 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion], @"timed out (changing)");
    
    STAssertTrue([refWarpSpeed isEqualToNumber: leader.config.warpSpeed], @"");
    STAssertTrue([refCaptainsLog isEqualToString: leader.config.captainsLog], @"");
    STAssertTrue([refShieldPercent isEqualToNumber: leader.config.shieldPercent], @"");
    [self ensureFarmsEqual:farms entityName:@"Config"];
    NSLog(@"%@ end", self.name);
}


- (void)testRepeatedStringChanges
{
    NSLog(@"%@ start", self.name);
    [self createAndStartFarms];

    // Leader sends an object to followers, then changes a string repeatedly
    Farm *leader = [farms objectAtIndex:0];
    [self connectFarms];
    
    int changeNumber = 0;
    NSString *refString = [NSString stringWithFormat:@"%d", changeNumber];
    leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    leader.config.captainsLog = refString;
    [leader.simperium save];
    [self expectAdditions:1 deletions:0 changes:0 fromLeader:leader expectAcks:YES];
    STAssertTrue([self waitForCompletion], @"timed out (adding)");
    
    for (changeNumber=1; changeNumber<20; changeNumber++) {
        refString = [NSString stringWithFormat:@"%@.%d", refString, changeNumber];
        leader.config.captainsLog = [NSString stringWithFormat:@"%@.%d", leader.config.captainsLog, changeNumber];
        [leader.simperium save];
        [self waitFor: (arc4random() % 200) / 1000.0];
    }
    [self waitFor:5];
    // Can't know how many to expect since some changes will get sent together
    //[self expectAdditions:0 deletions:0 changes:changeNumber-1 fromLeader:leader expectAcks:YES];
    //STAssertTrue([self waitForCompletion], @"timed out (changing)");
    
    STAssertTrue([refString isEqualToString: leader.config.captainsLog],
                 @"leader %@ != ref %@", leader.config.captainsLog, refString);
    [self ensureFarmsEqual:farms entityName:@"Config"];
    NSLog(@"%@ end", self.name); 
}



@end
