//
//  SimperiumSimpleTests.m
//  SimperiumSimpleTests
//
//  Created by Michael Johnston on 11-04-19.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SimperiumTypeTests.h"
#import "Config.h"
#import "Farm.h"
#import "SPBucket.h"

@implementation SimperiumTypeTests


- (void)testDate
{
    NSLog(@"%@ start", self.name);

    Farm *leader = [self createFarm:@"leader"];
    Farm *follower = [self createFarm:@"follower"];
    [leader start];
    [follower start];
    
    NSArray *farmArray = [NSArray arrayWithObjects:leader, follower, nil];
    [leader connect];
    [follower connect];
    [self waitFor:1.0];
    
    leader.config = [[leader.simperium bucketForName:@"Config"] insertNewObject];
    leader.config.captainsLog = @"1";
    [leader.simperium save];
    leader.expectedAcknowledgments = 1;
    follower.expectedAdditions = 1;
    STAssertTrue([self waitForCompletion: 4.0 farmArray:farmArray], @"timed out (adding)");
    [self resetExpectations: farmArray];
    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    NSLog(@"****************************DISCONNECT*************************");
    [follower disconnect];
    
    
    // Make sure there's no residual weirdness
    [self waitFor:1.0];
    
    NSString *refString = @"12";
    STAssertTrue([refString isEqualToString: leader.config.captainsLog],
                 @"leader %@ != ref %@", leader.config.captainsLog, refString);
    [self ensureFarmsEqual:farmArray entityName:@"Config"];
    NSLog(@"%@ end", self.name); 
}

@end
