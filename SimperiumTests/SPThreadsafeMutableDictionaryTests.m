//
//  SPThreadsafeMutableDictionaryTests.m
//  UnitTests
//
//  Created by Lantean on 1/14/21.
//  Copyright © 2021 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SPThreadsafeMutableDictionary.h"
#import "XCTestCase+Simperium.h"


#pragma mark - Constants

static NSUInteger const SPIterations                = 10000;
static NSUInteger const SPConcurrentWorkers         = 100;
static NSTimeInterval const SPExpectationTimeout    = 60.0;


#pragma mark - SPThreadsafeMutableDictionaryTests

@interface SPThreadsafeMutableDictionaryTests : XCTestCase

@end

@implementation SPThreadsafeMutableDictionaryTests

- (void)testMultipleConcurrentWorkersCanManipulateThreadsafeDictionaryWithoutTriggeringCrashes {

    SPThreadsafeMutableDictionary *dictionary = [SPThreadsafeMutableDictionary new];
    dispatch_group_t group = dispatch_group_create();

    // Launch concurrent workers
    for (NSInteger i = 0; ++i <= SPConcurrentWorkers; ) {
        dispatch_queue_t queue = dispatch_queue_create("com.simperium.SPThreadsafeMutableDictionaryTests", NULL);

        dispatch_group_enter(group);
        dispatch_async(queue, ^{

            for (NSInteger i = 0; ++i <= SPIterations; ) {
                NSString *key = [NSString stringWithFormat:@"%ld", (long)i];
                [dictionary setObject:@(i) forKey:key];
            }
            dispatch_group_leave(group);
        });
    }

    // Remember: Since it's a set, we should have 'SPSetIterations' objects
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{

        for (NSInteger i = 0; ++i <= SPIterations; ) {
            NSString *key = [NSString stringWithFormat:@"%ld", (long)i];
            NSNumber *value = [dictionary objectForKey:key];

            XCTAssertEqual(key, value.description);

            [dictionary removeObjectForKey:key];
            XCTAssertFalse([dictionary objectForKey:key], @"Delete Failed");
        }

        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
}

- (void)testCopyInternalStorageEffectivelyCopiesThePrivateDictionary {
    SPThreadsafeMutableDictionary *dictionary = [SPThreadsafeMutableDictionary new];
    for (NSInteger i = -1; ++i < SPIterations; ) {
        NSString *key = [NSString stringWithFormat:@"%ld", (long)i];
        [dictionary setObject:@(i) forKey:key];
    }

    NSDictionary *internalStorageCopy = [dictionary copyInternalStorage];
    XCTAssertEqual(internalStorageCopy.count, SPIterations);
}

@end
