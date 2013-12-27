//
//  SimperiumBinaryTests.m
//  Simperium
//
//  Created by Michael Johnston on 12-07-19.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SimperiumTests.h"
#import "Farm.h"
#import "Post.h"
#import "JSONKit+Simperium.h"
#import "SPEnvironment.h"
#import "NSString+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

NSInteger const SPTestBigFileSize			= 5;
NSInteger const SPTestBigFileBytes			= SPTestBigFileSize * 1024 * 1024;
NSTimeInterval const SPTestBigFileTimeout	= SPTestBigFileSize * 60;

NSInteger const SPTestSmallFileBytes		= 10 * 1024;
NSTimeInterval const SPTestSmallFileTimeout	= 20;


#pragma mark ====================================================================================
#pragma mark SimperiumBinaryTests
#pragma mark ====================================================================================


@interface SimperiumBinaryTests : SimperiumTests
@property (nonatomic, strong, readwrite) Farm		*leader;
@property (nonatomic, strong, readwrite) Farm		*follower;
@property (nonatomic, strong, readwrite) SPBucket	*leaderBucket;
@property (nonatomic, strong, readwrite) SPBucket	*followerBucket;
@end

@implementation SimperiumBinaryTests

+ (void)setUp {
	//	Note:
	//	=====
	//	This **HACK** will initialize a disposable bucket with a binary endpoint, specified with the constant BINARY_BACKEND.
	//	Remove this once we've got a reusable buckets mechanism.
	//
	//	Requirements:
	//		BINARY_BACKEND	: Should be set with the endpoint name
	//		ADMIN_TOKEN		: Should be an admin token (Generated with the dashboard)
	
	NSAssert(BINARY_BACKEND.length > 0, @"Please specify the binary endpoint!");
	NSAssert(ADMIN_TOKEN.length > 0, @"Please specify an admin token!");
	
	NSDictionary *rawPayload = @{ @"binary_backend": BINARY_BACKEND, @"key": BINARY_BACKEND};
	NSString *bucket = [[Post entityName] lowercaseString];
	NSString *rawUrl = [SPBaseURL stringByAppendingFormat:@"%@/__options__/i/%@", APP_ID, bucket];
	
	NSURL *url = [NSURL URLWithString:rawUrl];
	NSData *payload = [[rawPayload sp_JSONString] dataUsingEncoding:NSUTF8StringEncoding];
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:20.0];
	
	[request setValue:ADMIN_TOKEN forHTTPHeaderField:@"X-Simperium-Token"];
	request.HTTPBody = payload;
	request.HTTPMethod = @"POST";
	
	NSError *error = nil;
	[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
	NSAssert(error == nil, @"Error enabling binary backend");
}


#pragma mark ====================================================================================
#pragma mark Helpers
#pragma mark ====================================================================================

- (NSData *)randomDataWithLength:(NSUInteger)length {
    NSMutableData *mutableData = [NSMutableData dataWithCapacity: length];
    for (unsigned int i = 0; i < length; i++) {
        NSInteger randomBits = arc4random();
        [mutableData appendBytes: (void *) &randomBits length: 1];
    }
	
	return mutableData;
}


#pragma mark ====================================================================================
#pragma mark Execute Per IntegrationTest!
#pragma mark ====================================================================================

/**
	Note:
	=====
	Binary uploads generate metadata changes. In this scenario, it translates into 'expectedChanges'. I.e.:
		 Leader							Follower
		 1. Insert acknowledge			1.	Insert Sync
		 2. Binary Upload itself		2.	Binary Metadata change
		 3. Binary Metadata Change		3.	Binary Download
 */

- (void)setUp {
	[super setUp];
	
	// Load the farms
	self.leader = [self createFarm:@"leader"];
	self.follower = [self createFarm:@"follower"];
	
	// Start + Connect
    [self.leader start];
    [self.follower start];
		
    [self.leader connect];
    [self.follower connect];
	
	[self waitFor:1];
	
	// Load the buckets
	NSString *bucketName = [Post entityName];
	self.leaderBucket = [self.leader.simperium bucketForName:bucketName];
	self.followerBucket = [self.follower.simperium bucketForName:bucketName];
}

- (void)tearDown {
	// Cleanup
	[self.leaderBucket deleteAllObjects];
	[self.leader.simperium save];
	[self waitFor:5.0f];
	
	// Delete local data
	[self.leader.simperium signOutAndRemoveLocalData:YES];
	[self.follower.simperium signOutAndRemoveLocalData:YES];
	
	// And...
	self.leader = nil;
	self.follower = nil;
	
	self.leaderBucket = nil;
	self.followerBucket = nil;
	
	[super tearDown];
}


#pragma mark ====================================================================================
#pragma mark IntegrationTests!
#pragma mark ====================================================================================

- (void)testBigFiles {
	// Inserting + Adding a binary without connectivity. Should hit (NO) delegate!
    Post *leadPost = [self.leaderBucket insertNewObject];
    leadPost.picture = [self randomDataWithLength:SPTestBigFileBytes];
    [self.leader.simperium save];
				
	self.leader.expectedAcknowledgments = 1;
	self.leader.expectedBinaryUploads = 1;
	self.leader.expectedChanges = 1;

    self.follower.expectedAdditions = 1;
	self.follower.expectedBinaryDownloads = 1;
	self.follower.expectedChanges = 1;
	
    XCTAssertTrue([self waitForCompletion:SPTestBigFileTimeout farmArray:self.farms], @"BinarySync Upload/Download timeout");
	
	// Verify data integrity
	Post *followPost = [self.followerBucket objectForKey:leadPost.simperiumKey];
	XCTAssertEqualObjects(leadPost.picture, followPost.picture, @"BinarySync Integrity Error");
}

- (void)testNetworking {
	// Follower: Disconnect right now!
	[self.follower disconnect];
	
	// Leader: Insert
    Post *leadPost = [self.leaderBucket insertNewObject];
    leadPost.picture = [self randomDataWithLength:SPTestSmallFileBytes];
    [self.leader.simperium save];
		
	// Leader: Ensure Upload is ready
	self.leader.expectedAcknowledgments = 1;
	self.leader.expectedBinaryUploads = 1;
	self.leader.expectedChanges = 1;
	
    XCTAssertTrue([self waitForCompletion:SPTestSmallFileTimeout farmArray:@[self.leader] ], @"BinarySync Upload timeout");
		
	// Follower: Set expectations
    self.follower.expectedAdditions = 1;
    self.follower.expectedChanges = 1;
	self.follower.expectedBinaryDownloads = 1;
	
	// Follower: Enable / disable networking
    [self.follower connect];
	[self waitFor:1.0f];

	[self.follower disconnect];
	[self waitFor:1.0f];

	// Follower: Allow sync to happen. No changes expected, we'll just get the 'ready' version
    [self.follower connect];
    XCTAssertTrue([self waitForCompletion:SPTestSmallFileTimeout farmArray:@[self.follower] ], @"BinarySync Download timeout");
	
	// Verify data integrity	
	Post *followPost = [self.followerBucket objectForKey:leadPost.simperiumKey];
	XCTAssertNotNil(followPost, @"Post did not sync");
	XCTAssertEqualObjects(leadPost.picture, followPost.picture, @"BinarySync Integrity Error");
}

- (void)testUploads {
	// Insert a new object, right away
    Post *leadPost = [self.leaderBucket insertNewObject];
	[self.leader.simperium save];

	self.leader.expectedAcknowledgments = 1;
	self.leader.expectedChanges = 1;
	self.leader.expectedBinaryUploads = 1;
	
    self.follower.expectedAdditions = 1;
	self.follower.expectedBinaryDownloads = 1;
	self.follower.expectedChanges = 1;
	
    XCTAssertTrue([self waitForCompletion], @"BinarySync Upload/Download timeout");
	
	// Change the picture... several times. Only the latest version should get sync'ed
	for(NSInteger i = 0; ++i < 10; ) {
		leadPost.picture = [self randomDataWithLength:SPTestSmallFileBytes];
		[self.leader.simperium save];
		[self waitFor:0.1f];
	}
	self.leader.expectedChanges = 1;
	self.leader.expectedBinaryUploads = 1;
	
	self.follower.expectedBinaryDownloads = 1;
	self.follower.expectedChanges = 1;

    XCTAssertTrue([self waitForCompletion], @"BinarySync Upload/Download timeout");
	
	// Verify data integrity
	Post *followPost = [self.followerBucket objectForKey:leadPost.simperiumKey];
	XCTAssertEqualObjects(leadPost.picture, followPost.picture, @"BinarySync Integrity Error");
}

- (void)testDownloads {
	// Follower: Disconnect right now!
	[self.follower disconnect];
	
	// Leader: Insert
    Post *leadPost = [self.leaderBucket insertNewObject];
    leadPost.picture = [self randomDataWithLength:SPTestBigFileBytes];
    [self.leader.simperium save];
	
	// Leader: Ensure Upload is ready
	self.leader.expectedAcknowledgments = 1;
	self.leader.expectedBinaryUploads = 1;
	self.leader.expectedChanges = 1;
	
    XCTAssertTrue([self waitForCompletion:SPTestBigFileTimeout farmArray:@[self.leader] ], @"BinarySync Upload timeout");
	
	// Follower: Begin downloading the huge picture
    [self.follower connect];
	[self waitFor:0.1f];
	
	// Leader: Update the picture with a super small binary.
	// Goal: a new change comes in, while a previous download was in course
    leadPost.picture = [self randomDataWithLength:SPTestSmallFileBytes];
    [self.leader.simperium save];
	
	// Leader: Ensure Upload is ready
	self.leader.expectedBinaryUploads = 1;
	self.leader.expectedChanges = 1;
	
    XCTAssertTrue([self waitForCompletion:SPTestSmallFileTimeout farmArray:@[self.leader] ], @"BinarySync Upload timeout");
	
	// Follower: Should only sync the small file
    self.follower.expectedAdditions += 1;
    self.follower.expectedChanges += 2;
	self.follower.expectedBinaryDownloads += 1;

    XCTAssertTrue([self waitForCompletion:SPTestSmallFileTimeout farmArray:@[self.follower] ], @"BinarySync Download timeout");

	// Verify data integrity
	Post *followPost = [self.followerBucket objectForKey:leadPost.simperiumKey];
	XCTAssertEqualObjects(leadPost.picture, followPost.picture, @"BinarySync Integrity Error");
}

@end
