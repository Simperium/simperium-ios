//
//  SPManagedObjectTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 2/6/15.
//  Copyright (c) 2015 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Simperium.h"
#import "MockSimperium.h"
#import "Post.h"
#import "PostComment.h"
#import "Config.h"



#pragma mark ====================================================================================
#pragma mark SPManagedObjectTests
#pragma mark ====================================================================================

@interface SPManagedObjectTests : XCTestCase
@property (nonatomic, strong) MockSimperium             *simperium;
@property (nonatomic, strong) NSManagedObjectContext    *managedObjectContext;
@end

@implementation SPManagedObjectTests

- (void)setUp {
    MockSimperium *simperium    = [MockSimperium mockSimperium];
    [simperium setAllBucketPropertyMismatchFailsafeEnabled:true];
    
    self.simperium              = simperium;
    self.managedObjectContext   = simperium.managedObjectContext;
}

- (void)testSafeSetValueWithNilValue {
    Post *post = [NSEntityDescription insertNewObjectForEntityForName:[Post entityName] inManagedObjectContext:self.managedObjectContext];

    [self assertNoThrow:^{
        [post simperiumSetValue:nil forKey:NSStringFromSelector(@selector(title))];
        [post simperiumSetValue:nil forKey:NSStringFromSelector(@selector(comments))];
    }];
}

- (void)testSafeSetValueWithValidValues {
    Config *config      = [NSEntityDescription insertNewObjectForEntityForName:[Config entityName] inManagedObjectContext:self.managedObjectContext];
    
    NSNumber *warpSpeed     = @(1234);
    NSDecimalNumber *cost   = [NSDecimalNumber decimalNumberWithString:@"42"];
    NSDate *date            = [NSDate distantPast];
    
    [self assertNoThrow:^{
        [config simperiumSetValue:warpSpeed forKey:NSStringFromSelector(@selector(warpSpeed))];
        [config simperiumSetValue:cost      forKey:NSStringFromSelector(@selector(cost))];
        [config simperiumSetValue:date      forKey:NSStringFromSelector(@selector(date))];
    }];
    
    XCTAssertEqual(config.warpSpeed, warpSpeed, @"Invalid WarpSpeed");
    XCTAssertEqual(config.cost, cost,           @"Invalid WarpSpeed");
    XCTAssertEqual(config.date, date,           @"Invalid Date");
}

- (void)testSafeSetValueWithInvalidValues {
    Config *config  = [NSEntityDescription insertNewObjectForEntityForName:[Config entityName] inManagedObjectContext:self.managedObjectContext];
    config.cost     = nil;
    
    [self assertNoThrow:^{
        [config simperiumSetValue:@"String" forKey:NSStringFromSelector(@selector(warpSpeed))];
        [config simperiumSetValue:@"String" forKey:NSStringFromSelector(@selector(date))];
        [config simperiumSetValue:@"String" forKey:NSStringFromSelector(@selector(cost))];
    }];
    
    XCTAssertNil(config.warpSpeed,      @"This property should be nil due to type mismatch");
    XCTAssertNil(config.date,           @"This property should be nil due to type mismatch");
    XCTAssertNil(config.cost,           @"This property should be nil due to type mismatch");
    
    NSError *error = nil;
    [self.managedObjectContext save:&error];
    XCTAssertNil(error, @"Save shouldn't throw an error");
}

- (void)testSafeSetValueWithNilRelationship {
    PostComment *comment = [NSEntityDescription insertNewObjectForEntityForName:[PostComment entityName] inManagedObjectContext:self.managedObjectContext];

    [self assertNoThrow:^{
        [comment simperiumSetValue:nil forKey:NSStringFromSelector(@selector(post))];
    }];
}

- (void)testSafeSetValueWithInvalidRelationship {
    PostComment *comment    = [NSEntityDescription insertNewObjectForEntityForName:[PostComment entityName] inManagedObjectContext:self.managedObjectContext];
    NSNumber *invalid       = @(42);
    
    [self assertNoThrow:^{
        [comment simperiumSetValue:invalid forKey:NSStringFromSelector(@selector(post))];
    }];
    
    XCTAssertNil(comment.post, @"The post shouldn't have been set due to type mismatch");
}

@end
