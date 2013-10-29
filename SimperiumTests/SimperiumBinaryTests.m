//
//  SimperiumBinaryTests.m
//  Simperium
//
//  Created by Michael Johnston on 12-07-19.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SimperiumBinaryTests.h"
#import "Farm.h"
#import "Post.h"
#import "JSONKit.h"
#import "SPEnvironment.h"
#import "NSString+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

NSInteger const SPTestBigFileSize			= 1;
NSInteger const SPTestBigFileBytes			= SPTestBigFileSize * 1024 * 1024;
NSTimeInterval const SPTestBigFileTimeout	= SPTestBigFileSize * 60;

NSInteger const SPTestSmallFileBytes		= 10 * 1024;
NSTimeInterval const SPTestSmallFileTimeout	= 20;


#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SimperiumBinaryTests ()
@property (nonatomic, strong, readwrite) Farm *leader;
@property (nonatomic, strong, readwrite) Farm *follower;
@property (nonatomic, strong, readwrite) SPBucket *leaderBucket;
@property (nonatomic, strong, readwrite) SPBucket *followerBucket;
@end


#pragma mark ====================================================================================
#pragma mark SimperiumBinaryTests
#pragma mark ====================================================================================

@implementation SimperiumBinaryTests

+(void)setUp
{
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
	NSString *bucket = [[[self class] postBucket] lowercaseString];
	NSString *rawUrl = [SPBaseURL stringByAppendingFormat:@"%@/__options__/i/%@", APP_ID, bucket];
	
	NSURL *url = [NSURL URLWithString:rawUrl];
	NSData *payload = [rawPayload JSONData];
	
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

+(NSString *)postBucket
{
	static dispatch_once_t pred;
	static NSString* postBucket = nil;
	
	dispatch_once(&pred, ^{
		NSString *bucketSuffix = [[NSString sp_makeUUID] substringToIndex:8];
		postBucket = [NSString stringWithFormat:@"Post-%@", bucketSuffix];
	});
	
	return postBucket;
}

-(NSDictionary *)bucketOverrides
{
	[self uniqueBucketFor:nil];
	if(!self.overrides) {
		self.overrides = @{ @"Post" : [[self class] postBucket] };
	}
	return self.overrides;
}

-(NSData *)randomDataWithLength:(NSUInteger)length
{
    NSMutableData *mutableData = [NSMutableData dataWithCapacity: length];
    for (unsigned int i = 0; i < length; i++) {
        NSInteger randomBits = arc4random();
        [mutableData appendBytes: (void *) &randomBits length: 1];
    }
	
	return mutableData;
}


#pragma mark ====================================================================================
#pragma mark Execute Per UnitTest!
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

-(void)setUp
{
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
	NSString *bucketName = NSStringFromClass([Post class]);
	self.leaderBucket = [self.leader.simperium bucketForName:bucketName];
	self.followerBucket = [self.follower.simperium bucketForName:bucketName];
}

-(void)tearDown
{
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
#pragma mark UnitTests!
#pragma mark ====================================================================================

-(void)testBigFiles
{
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
	
    STAssertTrue([self waitForCompletion:SPTestBigFileTimeout farmArray:farms], @"BinarySync Upload/Download timeout");
	
	// Verify data integrity
	Post *followPost = [self.followerBucket objectForKey:leadPost.simperiumKey];
	STAssertEqualObjects(leadPost.picture, followPost.picture, @"BinarySync Integrity Error");
}

-(void)testNetworking
{
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
	
    STAssertTrue([self waitForCompletion:SPTestSmallFileTimeout farmArray:@[self.leader] ], @"BinarySync Upload timeout");
	
	// Follower: Enable / disable networking
    [self.follower connect];
	[self waitFor:1.0f];

	[self.follower disconnect];
	[self waitFor:1.0f];

	// Follower: Allow sync to happen. No changes expected, we'll just get the 'ready' version
    self.follower.expectedAdditions = 1;
	self.follower.expectedBinaryDownloads = 1;
	
    [self.follower connect];
    STAssertTrue([self waitForCompletion:SPTestSmallFileTimeout farmArray:@[self.follower] ], @"BinarySync Download timeout");
	
	// Verify data integrity	
	Post *followPost = [self.followerBucket objectForKey:leadPost.simperiumKey];
	STAssertNotNil(followPost, @"Post did not sync");
	STAssertEqualObjects(leadPost.picture, followPost.picture, @"BinarySync Integrity Error");
}

-(void)testUploads
{
	// Insert a new object, right away
    Post *leadPost = [self.leaderBucket insertNewObject];
	[self.leader.simperium save];

	self.leader.expectedAcknowledgments = 1;
	self.leader.expectedChanges = 1;
	self.leader.expectedBinaryUploads = 1;
	
    self.follower.expectedAdditions = 1;
	self.follower.expectedBinaryDownloads = 1;
	self.follower.expectedChanges = 1;
	
    STAssertTrue([self waitForCompletion], @"BinarySync Upload/Download timeout");
	
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
	
    STAssertTrue([self waitForCompletion], @"BinarySync Upload/Download timeout");
	
	// Verify data integrity
	Post *followPost = [self.followerBucket objectForKey:leadPost.simperiumKey];
	STAssertEqualObjects(leadPost.picture, followPost.picture, @"BinarySync Integrity Error");
}

@end
