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

@end

@implementation SPCoreDataStorageTests

- (void)testBucketListMechanism {
    MockSimperium* s                        = [MockSimperium mockSimperium];

    NSManagedObjectContext *mainContext     = s.managedObjectContext;
    NSManagedObjectContext *derivedContext  = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    derivedContext.parentContext            = mainContext;
    
    NSString *entityName                    = NSStringFromClass([Post class]);
    Post *mainPost                          = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:mainContext];
    Post *nestedPost                        = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:derivedContext];

    XCTAssertNotNil(mainPost.bucket,    @"Missing bucket in main context");
    XCTAssertNotNil(nestedPost.bucket,  @"Missing bucket in nested context");
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
	dispatch_group_t group			= dispatch_group_create();
	
	MockSimperium* s				= [MockSimperium mockSimperium];
	
	SPBucket* postBucket			= [s bucketForName:NSStringFromClass([Post class])];
	SPBucket* commentBucket			= [s bucketForName:NSStringFromClass([PostComment class])];
	
	SPCoreDataStorage* storage		= postBucket.storage;
	
	NSMutableArray* postKeys		= [NSMutableArray array];
	NSMutableArray* commentKeys		= [NSMutableArray array];
	
	// Insert Posts
	for (NSInteger i = 0; ++i <= kNumberOfPosts; ) {
		Post* post = [storage insertNewObjectForBucketName:postBucket.name simperiumKey:nil];
		post.title = [NSString stringWithFormat:@"Post [%ld]", (long)i];
		[postKeys addObject:post.simperiumKey];
		
		[storage save];
	}

	// Insert Comments
	dispatch_group_async(group, commentBucket.processorQueue, ^{
		id<SPStorageProvider> threadSafeStorage = [storage threadSafeStorage];
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
	});
	
	// Delete Posts
	dispatch_group_async(group, postBucket.processorQueue, ^{
		
		id<SPStorageProvider> threadSafeStorage = [storage threadSafeStorage];
		[threadSafeStorage beginCriticalSection];
		
		NSEnumerator* enumerator = [postKeys reverseObjectEnumerator];
		NSString* simperiumKey = nil;
		
		while (simperiumKey = (NSString*)[enumerator nextObject]) {
			
			Post* post = [threadSafeStorage objectForKey:simperiumKey bucketName:postBucket.name];
			[threadSafeStorage deleteObject:post];
			[threadSafeStorage save];
		}
		
		[threadSafeStorage finishCriticalSection];
	});
	
	StartBlock();
	dispatch_group_notify(group, dispatch_get_main_queue(), ^ {
		NSLog(@"Ready");
		EndBlock();
	});
	
	WaitUntilBlockCompletes();	
}

- (void)testUpdatingChildEntitiesWhileDeletingRootEntity
{	
	MockSimperium* s				= [MockSimperium mockSimperium];
	
	SPBucket* postBucket			= [s bucketForName:NSStringFromClass([Post class])];
	SPBucket* commentBucket			= [s bucketForName:NSStringFromClass([PostComment class])];
	
	SPCoreDataStorage* storage		= postBucket.storage;
	
	NSMutableArray* postKeys		= [NSMutableArray array];
	NSMutableArray* commentKeys		= [NSMutableArray array];
	dispatch_group_t group			= dispatch_group_create();
	
	// Insert Posts
	for (NSInteger i = 0; ++i <= kNumberOfPosts; ) {
		Post* post = [storage insertNewObjectForBucketName:postBucket.name simperiumKey:nil];
		post.title = [NSString stringWithFormat:@"Post [%ld]", (long)i];
		[postKeys addObject:post.simperiumKey];
		
		// Insert Comments
		for (NSInteger j = 0; ++j <= kCommentsPerPost; ) {
			PostComment* comment = [storage insertNewObjectForBucketName:commentBucket.name simperiumKey:nil];
			comment.content = [NSString stringWithFormat:@"Comment [%ld]", (long)j];
			[post addCommentsObject:comment];
			[commentKeys addObject:comment.simperiumKey];
		}
	}

	[storage save];
	
	// Update Comments
	StartBlock();
	
	dispatch_async(commentBucket.processorQueue, ^{
		for (NSString* simperiumKey in postKeys) {
			id<SPStorageProvider> threadSafeStorage = [storage threadSafeStorage];
			[threadSafeStorage beginSafeSection];
			
			Post* post = [threadSafeStorage objectForKey:simperiumKey bucketName:postBucket.name];
			for (PostComment* comment in post.comments) {
				comment.content = [NSString stringWithFormat:@"Updated Comment"];
			}

			// Delete Posts
			dispatch_group_async(group, postBucket.processorQueue, ^{
				id<SPStorageProvider> threadSafeStorage = [storage threadSafeStorage];
				[threadSafeStorage beginCriticalSection];
				
				[threadSafeStorage deleteAllObjectsForBucketName:postBucket.name];
				
				[threadSafeStorage finishCriticalSection];
			});
			
			[threadSafeStorage save];
			[threadSafeStorage finishSafeSection];
		}
		
		dispatch_group_notify(group, dispatch_get_main_queue(), ^ {
			NSLog(@"Ready");
			EndBlock();
		});
	});
	
	WaitUntilBlockCompletes();
}

- (void)testInsertedEntitiesAreImmediatelyAvailableInWorkerContexts
{
    // Setup an InMemory Core Data Stack
    NSManagedObjectContext* context				= [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    NSManagedObjectModel* model					= [NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]];
    NSPersistentStoreCoordinator* coordinator   = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    
    [coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:nil];
    
    NSString *postBucketName                    = NSStringFromClass([Post class]);
    XCTestExpectation *expectation              = [self expectationWithDescription:@"Insertion Callback Expectation"];
    
    // SPCoreDataStorage: Setup
    SPCoreDataStorage* storage  = [[SPCoreDataStorage alloc] initWithModel:model mainContext:context coordinator:coordinator];

    // SPStorageObserverAdapter: Make sure that the inserted objects are there, if query'ed
    SPStorageObserverAdapter *adapter           = [SPStorageObserverAdapter new];
    storage.delegate                            = adapter;
    
    adapter.callback = ^(NSSet *inserted, NSSet *updated, NSSet *deleted) {
        XCTAssert(inserted.count == kRaceConditionNumberOfEntities, @"Missing inserted entity");
        
        id<SPStorageProvider> threadsafeStorage = [storage threadSafeStorage];
        XCTAssertNotNil(threadsafeStorage, @"Missing Threadsafe Storage");
        
        for (SPManagedObject *mainMO in inserted) {
            NSManagedObject *localMO = [threadsafeStorage objectForKey:mainMO.simperiumKey bucketName:postBucketName];
            XCTAssertNotNil(localMO, @"Missing Object");
        }
        [expectation fulfill];
    };
    
    // Proceed inserting [kRaceConditionNumberOfEntities] entities
    for (NSInteger i = 0; ++i <= kRaceConditionNumberOfEntities; ) {
        [storage insertNewObjectForBucketName:postBucketName simperiumKey:nil];
    }
    [storage save];
    
    [self waitForExpectationsWithTimeout:kExpectationTimeout handler:^(NSError *error) {
        XCTAssertNil(error, @"SPCoreDataStorage's delegate method was never executed");
    }];
}

@end
