//
//  SimperiumSimpleTests.m
//  SimperiumSimpleTests
//
//  Created by Michael Johnston on 11-04-19.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SimperiumSimpleTests.h"
#import "Config.h"
#import "Farm.h"
#import "SPBucket.h"
#import "DiffMatchPatch.h"

@implementation SimperiumSimpleTests

- (NSDictionary *)bucketOverrides {
    // Each farm for each test case should share bucket overrides
    if (overrides == nil) {
        self.overrides = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [self uniqueBucketFor:@"Config"], @"Config", nil];
    }
    return overrides;
}

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
    leader.config.simperiumKey = @"config";
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

- (void)testSingleOfflineStringChange
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
    
    leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    leader.config.simperiumKey = @"config";
    leader.config.captainsLog = @"1";
    [leader.simperium save];
    leader.expectedAcknowledgments = 1;
    follower.expectedAdditions = 1;
    STAssertTrue([self waitForCompletion: 4.0 farmArray:farmArray], @"timed out (adding)");
    [self resetExpectations: farmArray];
    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    NSLog(@"****************************DISCONNECT*************************");
    [follower disconnect];
    
    follower.config = (Config *)[[follower.simperium bucketForName:@"Config"] objectForKey:@"config"];
    follower.config.captainsLog = @"12";
    follower.expectedAcknowledgments = 1;
    leader.expectedChanges = 1;
    [follower.simperium save];
    [self waitFor:1];
    NSLog(@"****************************RECONNECT*************************");
    [follower connect];
    STAssertTrue([self waitForCompletion:4.0 farmArray:farmArray], @"timed out (changing)");
    
    // Make sure there's no residual weirdness
    [self waitFor:1.0];
    
    NSString *refString = @"12";
    STAssertTrue([refString isEqualToString: leader.config.captainsLog],
                 @"leader %@ != ref %@", leader.config.captainsLog, refString);
    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    NSLog(@"%@ end", self.name); 
}


- (void)testSimultaneousOfflineStringChange
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
    [self waitFor:1.5];
    
    leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    leader.config.simperiumKey = @"config";
    leader.config.captainsLog = @"a";
    leader.expectedAcknowledgments = 1;
    follower.expectedAdditions = 1;
    [leader.simperium save];
    STAssertTrue([self waitForCompletion: 6.0 farmArray:farmArray], @"timed out (adding)");
    [self resetExpectations: farmArray];
    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    [follower disconnect];

    leader.config.captainsLog = @"ab";
    leader.expectedAcknowledgments = 1;
    [leader.simperium save];
    STAssertTrue([self waitForCompletion:6.0 farmArray:farmArray], @"timed out (changing)");
    [self resetExpectations:farmArray];
    
    follower.config = (Config *)[[follower.simperium bucketForName:@"Config"] objectForKey:@"config"];
    follower.config.captainsLog = @"ac";
    follower.expectedAcknowledgments = 1;
    follower.expectedChanges = 1;
    leader.expectedChanges = 1;
    [follower.simperium save];
    [follower connect];
    STAssertTrue([self waitForCompletion:6.0 farmArray:farmArray], @"timed out (changing)");
    
    // Make sure there's no residual weirdness
    [self waitFor:1.0];

    NSString *refString = @"abc";
    STAssertTrue([refString isEqualToString: leader.config.captainsLog],
                 @"leader %@ != ref %@", leader.config.captainsLog, refString);
    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    NSLog(@"%@ end", self.name); 
}

- (void)testOfflineCreationAndEditing
{
    NSLog(@"%@ start", self.name);
        
    // Leader creates an object offline, changes it, then connects
    Farm *leader = [self createFarm:@"leader"];
    
    // Change URL to an invalid one to simulate airplane mode (crude)
    [leader start];
    leader.simperium.rootURL = @"http://iosunittest.simperium.com:1234/1/";
    [leader connect];

    SPBucket *bucket = [leader.simperium bucketForName:@"Config"];
    NSArray *farmArray = [NSArray arrayWithObjects:leader, nil];
    
    [self waitFor:2];
    
    leader.config = [bucket insertNewObject];
    leader.config.simperiumKey = @"config";
    leader.config.captainsLog = @"1";
    [leader.simperium save];
    [self waitFor:1];
    
    // Wait a tick, make a change
    leader.config.captainsLog = @"123";
    [leader.simperium save];
    [self waitFor:1];

    // Wait a tick, make a change
    leader.config.captainsLog = @"123456";
    [leader.simperium save];
    [self waitFor:1];

    // Wait a tick, make a change
    leader.config.captainsLog = @"123456 09876";
    [leader.simperium save];
    [self waitFor:1];

    
    // Again with a second object
    Config *config2 = [bucket insertNewObject];
    config2.simperiumKey = @"config2";
    config2.captainsLog = @"a";
    [leader.simperium save];
    [self waitFor:1];
    
    config2.captainsLog = @"abc";
    [leader.simperium save];
    [self waitFor:1];

    config2.captainsLog = @"abcdef";
    [leader.simperium save];
    [self waitFor:1];

    
    NSLog(@"*****RECONNECTING******");
    [leader disconnect];
    
    [self waitFor:1];
    leader.simperium.rootURL = @"https://api.simperium.com/1/";
    [leader connect];
    [self waitFor:4];

    //leader.expectedAcknowledgments = 1;
    //STAssertTrue([self waitForCompletion: 4.0 farmArray:farmArray], @"timed out (adding)");
//    [self resetExpectations: farmArray];
//    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    
    //STAssertTrue([self waitForCompletion:4.0 farmArray:farmArray], @"timed out (changing)");
    
    
    NSString *refString = @"123456 09876";
    STAssertTrue([refString isEqualToString: leader.config.captainsLog],
                 @"leader %@ != ref %@", leader.config.captainsLog, refString);
    
    NSString *refString2 = @"abcdef";
    STAssertTrue([refString2 isEqualToString: config2.captainsLog],
                 @"leader %@ != ref %@", config2.captainsLog, refString2);
    
    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    NSLog(@"%@ end", self.name);
}


-(void)testDMP
{
    NSString *a = @"a";
    NSString *b = @"ab";
    NSString *c = @"ac";
    
    // Assorted hocus pocus ported from JS code
    NSError *error;
    DiffMatchPatch *dmp = [[DiffMatchPatch alloc] init];

    NSMutableArray * ac_diff =[dmp diff_mainOfOldString:a andNewString:c];
    NSMutableArray * ab_diff = [dmp diff_mainOfOldString:a andNewString:b];
    
    NSString *ac_diffs_delta = [dmp diff_toDelta:ac_diff];
    NSString *ab_diffs_delta = [dmp diff_toDelta:ab_diff];
    
    NSMutableArray *ac_diffs = [dmp diff_fromDeltaWithText:a andDelta:ac_diffs_delta error:&error];
    NSMutableArray *ac_patches = [dmp patch_makeFromOldString:a andDiffs:ac_diffs];
    NSLog(@"ac_diffs:%@", [ac_diffs description]);
    NSLog(@"ac_patches:%@", [ac_patches description]);

    NSMutableArray *ab_diffs = [dmp diff_fromDeltaWithText:a andDelta:ab_diffs_delta error:&error];
    NSMutableArray *ab_patches = [dmp patch_makeFromOldString:a andDiffs:ab_diffs];
    NSLog(@"ab_diffs:%@", [ab_diffs description]);
    NSLog(@"ab_patches:%@", [ab_patches description]);
    
    

    NSArray *ac_patch_apply = [dmp patch_apply:ac_patches toString:a];
    NSLog(@"ac_patch_apply: %@", [ac_patch_apply description]);
    NSString *interim_text = [[dmp patch_apply:ac_patches toString:a] objectAtIndex:0];
    NSLog(@"interim: %@, c:%@", interim_text, c);
    
    NSString *final_text = [[dmp patch_apply:ab_patches toString:interim_text] objectAtIndex:0];
    NSLog(@"final: %@", final_text);    
}

- (void)testSeededData
{
    NSLog(@"%@ start", self.name);
    [self createFarms];
    
    // Leader seeds an object
    Farm *leader = [farms objectAtIndex:0];
    
    NSNumber *refWarpSpeed = [NSNumber numberWithInt:2];
    leader.config = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:leader.managedObjectContext];
    //leader.config.simperiumKey = @"config";
    leader.config.warpSpeed = refWarpSpeed;
    
    [leader.managedObjectContext save:nil];
    
    // Now go online
    leader.simperium.networkEnabled = NO;
    
    // Problem: the above changes are marked by simperium, but starting the farm here will clear those changes
    // Solution? Add an alternative start: that doesn't clear?
    [leader start];
    leader.simperium.networkEnabled = YES;
    [leader connect];

    leader.expectedAcknowledgments = 1;
    STAssertTrue([self waitForCompletion], @"timed out");
        
    // The object was synced, now check followers to see if data was fully seeded
    for (Farm *farm in farms) {
        if (farm == leader)
            continue;
        [farm start];
        [farm connect];
    }
    [self resetExpectations: farms];
    [self expectAdditions:1 deletions:0 changes:0 fromLeader:leader expectAcks:NO];
    
    STAssertTrue([self waitForCompletion], @"timed out");
    
    [self ensureFarmsEqual:farms entityName:@"Config"];
    NSLog(@"%@ end", self.name);
}


@end
