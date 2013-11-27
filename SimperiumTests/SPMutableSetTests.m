//
//  SPMutableSetTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 11/26/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SPMutableSet.h"
#import "XCTestCase+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSUInteger const SPSetIterations		= 10000;
static NSUInteger const SPConcurrentWorkers	= 100;

#pragma mark ====================================================================================
#pragma mark SPMutableSetTests
#pragma mark ====================================================================================

@interface SPMutableSetTests : XCTestCase

@end

@implementation SPMutableSetTests

- (void)testCRUD {
	SPMutableSet *set = [SPMutableSet set];
	NSMutableSet *helper = [NSMutableSet set];
	
	for(NSInteger i = 0; ++i <= SPSetIterations; ) {
		[set addObject:@(i)];
		[helper addObject:@(i)];
	}
	
	XCTAssert(set.count == SPSetIterations, @"Inconsistent object count");
	XCTAssert(set.allObjects.count == SPSetIterations, @"Inconsistent object count");
	XCTAssert([set.allObjects isEqualToArray:helper.allObjects], @"Data Inconsistency");
	
	for(NSNumber* number in set.allObjects) {
		[set removeObject:number];
	}

	XCTAssert(set.count == 0, @"Error deleting object");
}

- (void)testThreading {
	
	// If you replace SPMutableSet with the regular NSMutableSet, you should see a nice error: "pointer being freed was not allocated"
	SPMutableSet *set = [SPMutableSet set];
	dispatch_group_t group = dispatch_group_create();
	
	// Launch concurrent workers
	for(NSInteger i = 0; ++i <= SPConcurrentWorkers; ) {
		dispatch_queue_t queue = dispatch_queue_create("com.simperium.SPMutableSetTests", NULL);
		
		dispatch_group_enter(group);
		dispatch_async(queue, ^{

			for(NSInteger i = 0; ++i <= SPSetIterations; ) {
				[set addObject:@(i)];
			}
			dispatch_group_leave(group);
		});
	}
	
	// Remember: Since it's a set, we should have 'SPSetIterations' objects
	StartBlock();
	
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		XCTAssert(set.count == SPSetIterations, @"Thread safety issue");
		
		for(NSInteger i = 0; ++i <= SPSetIterations; ) {
			XCTAssertTrue([set containsObject:@(i)], @"Missing object");
			[set removeObject:@(i)];
			XCTAssertFalse([set containsObject:@(i)], @"Missing object");
		}

		XCTAssertTrue(set.count == 0, @"The set should be empty!");
		EndBlock();
	});
	
	WaitUntilBlockCompletes();
}

@end
