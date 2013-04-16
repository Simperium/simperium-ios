//
//  SimperiumOfflineTests.m
//  SimperiumOfflineTests
//
//  Created by Michael Johnston on 11-04-19.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SimperiumOfflineTests.h"
#import "Config.h"
#import "Farm.h"
#import "SPBucket.h"
#import "DiffMatchPatch.h"

@implementation SimperiumOfflineTests

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


@end
