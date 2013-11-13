//
//  SimperiumRelationshipTests.m
//  SimperiumRelationshipTests
//
//  Created by Michael Johnston on 11-04-19.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SimperiumTests.h"
#import "Post.h"
#import "Comment.h"
#import "Farm.h"
#import "SPBucket.h"


@interface SimperiumRelationshipTests : SimperiumTests

@end

@implementation SimperiumRelationshipTests

-(NSDictionary *)bucketOverrides {
    // Each farm for each test case should share bucket overrides
    if (self.overrides == nil) {
        self.overrides = [NSDictionary dictionaryWithObjectsAndKeys:
                          [self uniqueBucketFor:@"Post"], @"Post",
                          [self uniqueBucketFor:@"Comment"], @"Comment", nil];
    }
    return self.overrides;
}

-(void)testSingleRelationship
{
    NSLog(@"%@ start", self.name);
    
    // Leader sends an object to a follower, follower goes offline, both make changes, follower reconnects
    Farm *leader = [self createFarm:@"leader"];
    Farm *follower = [self createFarm:@"follower"];
    [leader start];
    [follower start];
    leader.expectedIndexCompletions = 1;
    follower.expectedIndexCompletions = 1;
    [leader connect];
    [follower connect];
    XCTAssertTrue([self waitForCompletion: 4.0 farmArray:self.farms], @"timed out (initial index)");
    [self resetExpectations:self.farms];

    
    SPBucket *leaderPosts = [leader.simperium bucketForName:@"Post"];
    Post *post = (Post *)[leaderPosts insertNewObject];
    post.title = @"post title";
    
    SPBucket *leaderComments = [leader.simperium bucketForName:@"Comment"];
    Comment *comment = (Comment *)[leaderComments insertNewObject];
    comment.content = @"a comment";
    comment.post = post;
    
    leader.expectedAcknowledgments = 2;
    follower.expectedAdditions = 2;
    [leader.simperium save];
    XCTAssertTrue([self waitForCompletion: 4.0 farmArray:self.farms], @"timed out (adding)");
    
    // Ensure pending references have an opportunity to resolve
    [self waitFor:0.5];
    
    [self ensureFarmsEqual:self.farms entityName:@"Post"];
    [self ensureFarmsEqual:self.farms entityName:@"Comment"];

    NSLog(@"%@ end", self.name); 
}

-(void)testSingleRelationshipVariant
{
    NSLog(@"%@ start", self.name);
    
    Farm *leader = [self createFarm:@"leader"];
    Farm *follower = [self createFarm:@"follower"];
    [leader start];
    [follower start];

    NSArray *farmArray = [NSArray arrayWithObjects:leader, follower, nil];
    [leader connect];
    [follower connect];
        
    Comment *comment = [NSEntityDescription insertNewObjectForEntityForName:@"Comment" inManagedObjectContext:leader.managedObjectContext];
    comment.content = @"a comment";
    [leader.simperium save];
    
    Post *post = [NSEntityDescription insertNewObjectForEntityForName:@"Post" inManagedObjectContext:leader.managedObjectContext];
    post.title = @"post title";

    [post addCommentsObject:comment];
    
    leader.expectedAcknowledgments = 2;
    follower.expectedAdditions = 2;
    [leader.simperium save];
    XCTAssertTrue([self waitForCompletion: 4.0 farmArray:farmArray], @"timed out (adding)");
    
    // Ensure pending references have an opportunity to resolve
    [self waitFor:0.5];
    
    [self ensureFarmsEqual:farmArray entityName:@"Post"];
    [self ensureFarmsEqual:farmArray entityName:@"Comment"];
    
    NSLog(@"%@ end", self.name);
}


@end
