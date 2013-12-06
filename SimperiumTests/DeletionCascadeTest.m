//
//  DeletionCascadeTest.m
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


static NSInteger const kNumberOfPosts		= 10;
static NSInteger const kCommentsPerPost		= 50;
static NSInteger const kStressIterations	= 500;

@interface DeletionCascadeTest : XCTestCase

@end

@implementation DeletionCascadeTest

- (void)testStress {
	for (NSInteger i = 0; ++i <= kStressIterations; ) {
		NSLog(@"<> Stress Iteration %d", i);
		[self testInsertion];
		[self testUpdates];
	}
}

- (void)testInsertion
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
		post.title = [NSString stringWithFormat:@"Post [%d]", i];
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
				comment.content = [NSString stringWithFormat:@"Comment [%d]", j];
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

- (void)testUpdates
{	
	MockSimperium* s				= [MockSimperium mockSimperium];
	
	SPBucket* postBucket			= [s bucketForName:NSStringFromClass([Post class])];
	SPBucket* commentBucket			= [s bucketForName:NSStringFromClass([PostComment class])];
	
	SPCoreDataStorage* storage		= postBucket.storage;
	
	NSMutableArray* postKeys		= [NSMutableArray array];
	NSMutableArray* commentKeys		= [NSMutableArray array];
	
	// Insert Posts
	for (NSInteger i = 0; ++i <= kNumberOfPosts; ) {
		Post* post = [storage insertNewObjectForBucketName:postBucket.name simperiumKey:nil];
		post.title = [NSString stringWithFormat:@"Post [%d]", i];
		[postKeys addObject:post.simperiumKey];
		
		[storage save];
	}
	
	// Insert Comments
	for (NSString* simperiumKey in postKeys) {
		Post* post = [storage objectForKey:simperiumKey bucketName:postBucket.name];
		for (NSInteger j = 0; ++j <= kCommentsPerPost; ) {
			PostComment* comment = [storage insertNewObjectForBucketName:commentBucket.name simperiumKey:nil];
			comment.content = [NSString stringWithFormat:@"Comment [%d]", j];
			[post addCommentsObject:comment];
			[commentKeys addObject:comment.simperiumKey];
		}
		
		[storage save];
	}

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
			dispatch_async(postBucket.processorQueue, ^{
				id<SPStorageProvider> threadSafeStorage = [storage threadSafeStorage];
				[threadSafeStorage beginCriticalSection];
				
				[threadSafeStorage deleteAllObjectsForBucketName:postBucket.name];
				
				[threadSafeStorage finishCriticalSection];
			});
			
			[threadSafeStorage save];
			[threadSafeStorage finishSafeSection];
		}
	});
	
	EndBlock();
	
	WaitUntilBlockCompletes();
}


@end
