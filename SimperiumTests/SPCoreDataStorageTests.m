//
//  SPCoreDataStorageTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 12/5/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Simperium.h"
#import "MockSimperium.h"
#import "Simperium+Internals.h"
#import "Post.h"
#import "PostComment.h"
#import "SPCoreDataStorage.h"
#import "SPStorageObserverAdapter.h"
#import "SPBucket+Internals.h"




static NSInteger const kNumberOfPosts                   = 10;
static NSInteger const kCommentsPerPost                 = 50;
static NSInteger const kStressIterations                = 100;
static NSInteger const kRaceConditionNumberOfEntities   = 1000;
static NSTimeInterval const kExpectationTimeout         = 60.0;


@interface SPCoreDataStorageTests : XCTestCase
@property (nonatomic, strong) Simperium*            simperium;
@property (nonatomic, strong) SPCoreDataStorage*    storage;
@end


@implementation SPCoreDataStorageTests

- (void)setUp {
    self.simperium  = [MockSimperium mockSimperium];
    self.storage    = _simperium.coreDataStorage;
}

- (void)testBucketListMechanism {
    NSManagedObjectContext *mainContext     = self.simperium.managedObjectContext;
    NSManagedObjectContext *derivedContext  = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    derivedContext.parentContext            = mainContext;
    
    NSString *entityName                    = NSStringFromClass([Post class]);
    Post *mainPost                          = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:mainContext];
    XCTAssertNotNil(mainPost.bucket, @"Missing bucket in main context");
    
    [derivedContext performBlockAndWait:^{
        Post *nestedPost                    = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:derivedContext];
        XCTAssertNotNil(nestedPost.bucket, @"Missing bucket in nested context");
    }];
}

- (void)testStress {
	for (NSInteger i = 0; ++i <= kStressIterations; ) {
		NSLog(@"<> Stress Iteration %ld", (long)i);
		
		NSDate *reference = [NSDate date];
		[self testInsertingChildEntitiesWhileDeletingRootEntity];
		NSLog(@" >> Insertion Delta: %f", reference.timeIntervalSinceNow);
		
		reference = [NSDate date];
		[self testUpdatingChildEntitiesWhileDeletingRootEntity];
		NSLog(@" >> Updates Delta: %f", reference.timeIntervalSinceNow);
	}
}

- (void)testInsertingChildEntitiesWhileDeletingRootEntity
{
	SPBucket* postBucket			= [self.simperium bucketForName:NSStringFromClass([Post class])];
	SPBucket* commentBucket			= [self.simperium bucketForName:NSStringFromClass([PostComment class])];
		
	NSMutableArray* postKeys		= [NSMutableArray array];
	NSMutableArray* commentKeys		= [NSMutableArray array];
	
	// Insert Posts
	for (NSInteger i = 0; ++i <= kNumberOfPosts; ) {
		Post* post = [self.storage insertNewObjectForBucketName:postBucket.name simperiumKey:nil];
		post.title = [NSString stringWithFormat:@"Post [%ld]", (long)i];
		[postKeys addObject:post.simperiumKey];
		
		[self.storage save];
	}

	// Insert Comments
    XCTestExpectation *insertExpectation = [self expectationWithDescription:@"Insert Expectation"];
    
	dispatch_async(commentBucket.processorQueue, ^{
		id<SPStorageProvider> threadSafeStorage = [self.storage threadSafeStorage];
		[threadSafeStorage beginSafeSection];
		
		for (NSString* simperiumKey in postKeys) {
			
			Post* post = [threadSafeStorage objectForKey:simperiumKey bucketName:postBucket.name];
			for (NSInteger j = 0; ++j <= kCommentsPerPost; ) {
				PostComment* comment = [threadSafeStorage insertNewObjectForBucketName:commentBucket.name simperiumKey:nil];
				comment.content = [NSString stringWithFormat:@"Comment [%ld]", (long)j];
				[post addCommentsObject:comment];
				[commentKeys addObject:comment.simperiumKey];
			}
		}
		
		[threadSafeStorage save];
		[threadSafeStorage finishSafeSection];
        [insertExpectation fulfill];
	});
	
	// Delete Posts
    XCTestExpectation *deleteExpectation = [self expectationWithDescription:@"Delete Expectation"];
    
	dispatch_async(postBucket.processorQueue, ^{
		
		id<SPStorageProvider> threadSafeStorage = [self.storage threadSafeStorage];
		[threadSafeStorage beginCriticalSection];
		
		NSEnumerator* enumerator = [postKeys reverseObjectEnumerator];
		NSString* simperiumKey = nil;
		
		while (simperiumKey = (NSString*)[enumerator nextObject]) {
			
			Post* post = [threadSafeStorage objectForKey:simperiumKey bucketName:postBucket.name];
			[threadSafeStorage deleteObject:post];
			[threadSafeStorage save];
		}
		
		[threadSafeStorage finishCriticalSection];
        [deleteExpectation fulfill];
	});
	
    [self waitForExpectationsWithTimeout:kExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
}

- (void)testUpdatingChildEntitiesWhileDeletingRootEntity
{
	SPBucket* postBucket			= [self.simperium bucketForName:NSStringFromClass([Post class])];
	SPBucket* commentBucket			= [self.simperium bucketForName:NSStringFromClass([PostComment class])];
		
	NSMutableArray* postKeys		= [NSMutableArray array];
	
	// Insert Posts
	for (NSInteger i = 0; ++i <= kNumberOfPosts; ) {
		Post* post = [self.storage insertNewObjectForBucketName:postBucket.name simperiumKey:nil];
		post.title = [NSString stringWithFormat:@"Post [%ld]", (long)i];
		[postKeys addObject:post.simperiumKey];
		
		// Insert Comments
		for (NSInteger j = 0; ++j <= kCommentsPerPost; ) {
			PostComment* comment = [self.storage insertNewObjectForBucketName:commentBucket.name simperiumKey:nil];
			comment.content = [NSString stringWithFormat:@"Comment [%ld]", (long)j];
			[post addCommentsObject:comment];
		}
	}
	
	// Update Comments when the saveOP is effectively ready
    XCTestExpectation *updateExpectation = [self expectationWithDescription:@"Update Expectation"];
	
    SPStorageObserverAdapter *adapter = [SPStorageObserverAdapter new];
    adapter.didSaveCallback = ^(NSSet *inserted, NSSet *updated, NSSet *deleted) {
        dispatch_async(commentBucket.processorQueue, ^{
            for (NSString* simperiumKey in postKeys) {
                id<SPStorageProvider> threadSafeStorage = [self.storage threadSafeStorage];
                [threadSafeStorage beginSafeSection];
                
                Post* post = [threadSafeStorage objectForKey:simperiumKey bucketName:postBucket.name];
                for (PostComment* comment in post.comments) {
                    comment.content = [NSString stringWithFormat:@"Updated Comment"];
                }

                // Delete Posts
                dispatch_async(postBucket.processorQueue, ^{
                    id<SPStorageProvider> threadSafeStorage = [self.storage threadSafeStorage];
                    
                    [threadSafeStorage beginCriticalSection];
                    [threadSafeStorage deleteAllObjectsForBucketName:postBucket.name];
                    [threadSafeStorage finishCriticalSection];
                });
                
                [threadSafeStorage save];
                [threadSafeStorage finishSafeSection];
            }

            dispatch_async(postBucket.processorQueue, ^{
                [updateExpectation fulfill];
            });
        });
    };
    
    // Save, and wait for the process to be ready!
    self.storage.delegate = adapter;
	[self.storage save];
    
    [self waitForExpectationsWithTimeout:kExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"SPCoreDataStorage's delegate method was never executed");
    }];
}

- (void)testInsertedEntitiesAreImmediatelyAvailableInWorkerContexts {
    
    // SPStorageObserverAdapter: Make sure that the inserted objects are there, if query'ed
    SPStorageObserverAdapter *adapter           = [SPStorageObserverAdapter new];
    self.storage.delegate                       = adapter;
    
    SPBucket *postBucket                        = [self.simperium bucketForName:NSStringFromClass([Post class])];
    XCTestExpectation *expectation              = [self expectationWithDescription:@"Insertion Callback Expgiectation"];
    
    adapter.didSaveCallback = ^(NSSet *inserted, NSSet *updated, NSSet *deleted) {
        XCTAssert(inserted.count == kRaceConditionNumberOfEntities, @"Missing inserted entity");
        
        dispatch_async(postBucket.processorQueue, ^{
            id<SPStorageProvider> threadsafeStorage = [self.storage threadSafeStorage];
            XCTAssertNotNil(threadsafeStorage, @"Missing Threadsafe Storage");
            
            [threadsafeStorage beginSafeSection];
            for (SPManagedObject *mainMO in inserted) {
                NSManagedObject *localMO = [threadsafeStorage objectForKey:mainMO.simperiumKey bucketName:postBucket.name];
                XCTAssertNotNil(localMO, @"Missing Object");
            }
            [threadsafeStorage finishSafeSection];
            [expectation fulfill];
        });
    };
    
    // Proceed inserting [kRaceConditionNumberOfEntities] entities
    for (NSInteger i = 0; ++i <= kRaceConditionNumberOfEntities; ) {
        [self.storage insertNewObjectForBucketName:postBucket.name simperiumKey:nil];
    }
    [self.storage save];
    
    [self waitForExpectationsWithTimeout:kExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"SPCoreDataStorage's delegate method was never executed");
    }];
}

- (void)testDeletedEntitySimperiumKeyIsAccessible {
    
    NSString *postBucketName                    = NSStringFromClass([Post class]);
    XCTestExpectation *expectation              = [self expectationWithDescription:@"Insertion Callback Expgiectation"];
    
    // SPStorageObserverAdapter: Make sure that the inserted objects are there, if query'ed
    SPStorageObserverAdapter *adapter           = [SPStorageObserverAdapter new];
    self.storage.delegate                       = adapter;
    
    adapter.willSaveCallback = ^(NSSet *inserted, NSSet *updated, NSSet *deleted) {
        if (inserted.count) {
            return;
        }
        
        XCTAssert(deleted.count == kRaceConditionNumberOfEntities, @"Missing inserted entity");
        
        for (SPManagedObject *mainMO in deleted) {
            XCTAssertNotNil(mainMO.simperiumKey, @"SimperiumKey is not accessible");
        }
        [expectation fulfill];
    };
    
    // Proceed inserting [kRaceConditionNumberOfEntities] entities
    for (NSInteger i = 0; ++i <= kRaceConditionNumberOfEntities; ) {
        [self.storage insertNewObjectForBucketName:postBucketName simperiumKey:nil];
    }
    [self.storage save];
    
    // Nuke the entities
    [self.storage deleteAllObjectsForBucketName:postBucketName];
    [self.storage save];
    
    [self waitForExpectationsWithTimeout:kExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"SPCoreDataStorage's delegate method was never executed");
    }];
}

@end
