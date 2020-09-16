//
//  SPCoreDataStorageTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 12/5/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MockSimperium.h"
#import "Simperium+Internals.h"
#import "SPBucket+Internals.h"

#import "Post.h"
#import "PostComment.h"

#import "SPCoreDataStorage.h"
#import "SPStorageObserverAdapter.h"
#import "SPCoreDataStorage+Mock.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSInteger const SPNumberOfPosts                   = 10;
static NSInteger const SPCommentsPerPost                 = 50;
static NSInteger const SPStressIterations                = 100;
static NSInteger const SPRaceConditionNumberOfEntities   = 1000;
static NSTimeInterval const SPExpectationTimeout         = 60.0;


#pragma mark ====================================================================================
#pragma mark SPCoreDataStorageTests
#pragma mark ====================================================================================

@interface SPCoreDataStorageTests : XCTestCase
@property (nonatomic, strong) Simperium*            simperium;
@property (nonatomic, strong) SPCoreDataStorage*    storage;
@end


@implementation SPCoreDataStorageTests

- (void)setUp {
    self.simperium  = [MockSimperium mockSimperium];
    self.storage    = _simperium.coreDataStorage;
}

- (void)tearDown {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Signout Expectation"];
    
    [self.simperium signOutAndRemoveLocalData:false completion:^{
        [expectation fulfill];
    }];
    
    NSLog(@"Logged Out");
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:nil];
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

- (void)testStressUpsertingWhileDeletingRootEntities {
	for (NSInteger i = 0; ++i <= SPStressIterations; ) {
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
	for (NSInteger i = 0; ++i <= SPNumberOfPosts; ) {
		Post* post = [self.storage insertNewObjectForBucketName:postBucket.name simperiumKey:nil];
		post.title = [NSString stringWithFormat:@"Post [%ld]", (long)i];
		[postKeys addObject:post.simperiumKey];
		
		[self.storage save];
	}

	// Insert Comments
    XCTestExpectation *commentsExpectation = [self expectationWithDescription:@"Comments Expectation"];
    
	dispatch_async(commentBucket.processorQueue, ^{
		id<SPStorageProvider> threadSafeStorage = [self.storage threadSafeStorage];

        for (NSString* simperiumKey in postKeys) {
            XCTestExpectation *expectation = [self expectationWithDescription:@"Insert Expectation"];

            [threadSafeStorage performSafeBlockAndWait:^{

                Post* post = [threadSafeStorage objectForKey:simperiumKey bucketName:postBucket.name];
                if (post == nil) {
                    return;
                }

                for (NSInteger j = 0; ++j <= SPCommentsPerPost; ) {
                    PostComment* comment = [threadSafeStorage insertNewObjectForBucketName:commentBucket.name simperiumKey:nil];
                    comment.content = [NSString stringWithFormat:@"Comment [%ld]", (long)j];
                    [post addCommentsObject:comment];
                    [commentKeys addObject:comment.simperiumKey];
                }

                [threadSafeStorage save];
                [expectation fulfill];
            }];
        }
        
        [commentsExpectation fulfill];
	});
	
	// Delete Posts
    XCTestExpectation *postExpectation = [self expectationWithDescription:@"Delete Expectation"];
    
	dispatch_async(postBucket.processorQueue, ^{
		
		id<SPStorageProvider> threadSafeStorage = [self.storage threadSafeStorage];
        NSEnumerator* enumerator = [postKeys reverseObjectEnumerator];
        NSString* simperiumKey = nil;

        while (simperiumKey = (NSString*)[enumerator nextObject]) {
            XCTestExpectation *expectation = [self expectationWithDescription:@"Insert Expectation"];

            [threadSafeStorage performCriticalBlockAndWait:^{
                Post* post = [threadSafeStorage objectForKey:simperiumKey bucketName:postBucket.name];
                [threadSafeStorage deleteObject:post];
                [threadSafeStorage save];
                [expectation fulfill];
            }];
        }
		
        [postExpectation fulfill];
	});
	
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectations Timeout");
    }];
}

- (void)testUpdatingChildEntitiesWhileDeletingRootEntity
{
	SPBucket* postBucket			= [self.simperium bucketForName:NSStringFromClass([Post class])];
	SPBucket* commentBucket			= [self.simperium bucketForName:NSStringFromClass([PostComment class])];
		
	NSMutableArray* postKeys		= [NSMutableArray array];
	
	// Insert Posts
	for (NSInteger i = 0; ++i <= SPNumberOfPosts; ) {
		Post* post = [self.storage insertNewObjectForBucketName:postBucket.name simperiumKey:nil];
		post.title = [NSString stringWithFormat:@"Post [%ld]", (long)i];
		[postKeys addObject:post.simperiumKey];
		
		// Insert Comments
		for (NSInteger j = 0; ++j <= SPCommentsPerPost; ) {
			PostComment* comment = [self.storage insertNewObjectForBucketName:commentBucket.name simperiumKey:nil];
			comment.content = [NSString stringWithFormat:@"Comment [%ld]", (long)j];
			[post addCommentsObject:comment];
		}
	}
	
	// Update Comments when the saveOP is effectively ready
    XCTestExpectation *updateExpectation = [self expectationWithDescription:@"Update Expectation"];
	
    SPStorageObserverAdapter *adapter = [SPStorageObserverAdapter new];
    adapter.didSaveCallback = ^(NSSet *inserted, NSSet *updated) {
        dispatch_async(commentBucket.processorQueue, ^{
            for (NSString* simperiumKey in postKeys) {
                id<SPStorageProvider> threadSafeStorage = [self.storage threadSafeStorage];
                [threadSafeStorage performSafeBlockAndWait:^{
                    
                    Post* post = [threadSafeStorage objectForKey:simperiumKey bucketName:postBucket.name];
                    for (PostComment* comment in post.comments) {
                        comment.content = [NSString stringWithFormat:@"Updated Comment"];
                    }

                    // Delete Posts
                    dispatch_async(postBucket.processorQueue, ^{
                        id<SPStorageProvider> threadSafeStorage = [self.storage threadSafeStorage];
                        
                        [threadSafeStorage performCriticalBlockAndWait:^{
                            [threadSafeStorage deleteAllObjectsForBucketName:postBucket.name];
                        }];
                    });
                    
                    [threadSafeStorage save];
                }];
            }

            dispatch_async(postBucket.processorQueue, ^{
                [updateExpectation fulfill];
            });
        });
    };
    
    // Save, and wait for the process to be ready!
    self.storage.delegate = adapter;
	[self.storage save];
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"SPCoreDataStorage's delegate method was never executed");
    }];
}

- (void)testInsertedEntitiesAreImmediatelyAvailableInWorkerContexts {
    
    // SPStorageObserverAdapter: Make sure that the inserted objects are there, if query'ed
    SPStorageObserverAdapter *adapter           = [SPStorageObserverAdapter new];
    self.storage.delegate                       = adapter;
    
    SPBucket *postBucket                        = [self.simperium bucketForName:NSStringFromClass([Post class])];
    XCTestExpectation *expectation              = [self expectationWithDescription:@"Insertion Callback Expgiectation"];
    
    adapter.didSaveCallback = ^(NSSet *inserted, NSSet *updated) {
        XCTAssert(inserted.count == SPRaceConditionNumberOfEntities, @"Missing inserted entity");
        
        NSMutableSet *insertedKeys = [NSMutableSet set];
        for (SPManagedObject *object in inserted) {
            [insertedKeys addObject:object.simperiumKey];
        }
        
        dispatch_async(postBucket.processorQueue, ^{
            id<SPStorageProvider> threadsafeStorage = [self.storage threadSafeStorage];
            XCTAssertNotNil(threadsafeStorage, @"Missing Threadsafe Storage");
            
            [threadsafeStorage performSafeBlockAndWait:^{
                
                for (NSString *simperiumKey in insertedKeys) {
                    NSManagedObject *localMO = [threadsafeStorage objectForKey:simperiumKey bucketName:postBucket.name];
                    XCTAssertNotNil(localMO, @"Missing Object");
                }
            }];
            [expectation fulfill];
        });
    };
    
    // Proceed inserting [kRaceConditionNumberOfEntities] entities
    for (NSInteger i = 0; ++i <= SPRaceConditionNumberOfEntities; ) {
        [self.storage insertNewObjectForBucketName:postBucket.name simperiumKey:nil];
    }
    [self.storage save];
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"SPCoreDataStorage's delegate method was never executed");
    }];
}

- (void)testKeysForDeletedEntitiesIsAccessible {
    
    NSString *postBucketName                    = NSStringFromClass([Post class]);
    XCTestExpectation *expectation              = [self expectationWithDescription:@"Insertion Callback Expgiectation"];
    
    // SPStorageObserverAdapter: Make sure that the inserted objects are there, if query'ed
    SPStorageObserverAdapter *adapter           = [SPStorageObserverAdapter new];
    
    adapter.willSaveCallback = ^(NSSet *deleted) {
        XCTAssert(deleted.count == SPRaceConditionNumberOfEntities, @"Missing inserted entity");
        
        for (SPManagedObject *mainMO in deleted) {
            XCTAssertNotNil(mainMO.simperiumKey, @"SimperiumKey is not accessible");
        }
        [expectation fulfill];
    };
    
    // Proceed inserting [kRaceConditionNumberOfEntities] entities
    for (NSInteger i = 0; ++i <= SPRaceConditionNumberOfEntities; ) {
        [self.storage insertNewObjectForBucketName:postBucketName simperiumKey:nil];
    }
    
    [self.storage save];
    
    // Nuke the entities
    self.storage.delegate = adapter;
    [self.storage deleteAllObjectsForBucketName:postBucketName];
    [self.storage save];
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"SPCoreDataStorage's delegate method was never executed");
    }];
}

- (void)testMultipleContextSaveDontMissEntities {
    
    NSString *postBucketName                    = NSStringFromClass([Post class]);
    XCTestExpectation *expectation              = [self expectationWithDescription:@"Insertion Callback Expectation"];
    
    // SPStorageObserverAdapter: Make sure that the inserted objects are there, if query'ed
    SPStorageObserverAdapter *adapter           = [SPStorageObserverAdapter new];
    self.storage.delegate                       = adapter;

    __block NSInteger insertCount               = 0;
    
    adapter.didSaveCallback = ^(NSSet *inserted, NSSet *updated) {
        insertCount += inserted.count;
        if (insertCount == SPStressIterations) {
            [expectation fulfill];
        }
    };
    
    // Proceed inserting [kRaceConditionNumberOfEntities] entities
    for (NSInteger i = 0; ++i <= SPStressIterations; ) {
        [self.storage insertNewObjectForBucketName:postBucketName simperiumKey:nil];
        [self.storage save];
    }
    
    [self waitForExpectationsWithTimeout:SPExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"Inserted Objects never reached DidSave Callback");
    }];
}

- (void)testDeletedEntitiesInWorkersWithUnmergedChangesAnywhereDontTriggerInaccessibleObjectException {

    [SPCoreDataStorage test_simulateWorkerCannotMergeChangesAnywhere];
    
    [self _testDeletedEntitiesInWorkersDontTriggerInaccessibleObjectException];
    
    [SPCoreDataStorage test_undoWorkerCannotMergeChangesAnywhere];
}

- (void)testDeletedEntitiesInWorkersWithMergedChangesIntoWriterDontTriggerInaccessibleObjectException {

    [SPCoreDataStorage test_simulateWorkerOnlyMergesChangesIntoWriter];
    
    [self _testDeletedEntitiesInWorkersDontTriggerInaccessibleObjectException];
    
    [SPCoreDataStorage test_undoWorkerOnlyMergesChangesIntoWriter];
}


#pragma mark - Private Methods

- (void)_testDeletedEntitiesInWorkersDontTriggerInaccessibleObjectException {
    
    // Insert an entity and make sure it's stored
    NSString *postBucketName        = NSStringFromClass([Post class]);
    SPManagedObject *post           = [self.storage insertNewObjectForBucketName:postBucketName simperiumKey:nil];
    NSString *postSimperiumKey      = post.simperiumKey;
    
    [self.storage save];
    [self.storage test_waitUntilSaveCompletes];
    
    // Make sure it's faulted
    [self.storage.mainManagedObjectContext refreshObject:post mergeChanges:false];
    XCTAssert(post.isFault, @"Should be faulted!");
    
    // Simulate a Background Worker
    dispatch_group_t group          = dispatch_group_create();
    dispatch_queue_t workerQueue    = dispatch_queue_create(nil, nil);
    
    dispatch_group_enter(group);
    dispatch_async(workerQueue, ^{
        
        // Leave the group as soon as possible
        SPStorageObserverAdapter *adapter       = [SPStorageObserverAdapter new];
        adapter.didSaveCallback = ^(NSSet* inserted, NSSet* updated){
            dispatch_group_leave(group);
        };
        
        // Threadsafe Storage
        SPCoreDataStorage *threadSafeStorage    = [self.storage threadSafeStorage];
        threadSafeStorage.delegate              = adapter;
        
        SPManagedObject *workerMO               = [threadSafeStorage objectForKey:postSimperiumKey bucketName:postBucketName];
        [threadSafeStorage deleteObject:workerMO];
        [threadSafeStorage save];
    });
    
    // Lock the Main Thread until the worker saves. This should prevent 'didSaveCallback' from being executed
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Attempt to fault the entity
    XCTAssertNoThrow(post.simperiumKey, @"This shouldn't trigger an exception");
}

@end
