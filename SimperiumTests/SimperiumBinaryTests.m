//
//  SimperiumBinaryTests.m
//  Simperium
//
//  Created by Michael Johnston on 12-07-19.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SimperiumBinaryTests.h"
#import "Farm.h"


@implementation SimperiumBinaryTests

-(NSData *)randomDataWithBytes: (NSUInteger)length
{
    NSMutableData *mutableData = [NSMutableData dataWithCapacity: length];
    for (unsigned int i = 0; i < length; i++) {
        NSInteger randomBits = arc4random();
        [mutableData appendBytes: (void *) &randomBits length: 1];
    }
	
	return mutableData;
}

-(void)testSmallBinaryFile
{
    NSLog(@"%@ start", self.name);
	
#warning TODO: Write UnitTests!

/*
 -	Test Login:
 		-	Before auth, sync ops should NOT be accepted << ok?
 		-	Sync should begin after the user gets authenticated
 -	Test Logout:
 		-	Pending Downloads / Uploads should get killed, and queues emptied
 -	Test Resume:
 		-	Pending Uploads:
 				-	If the object was deleted, the pending should be removed, and nothing should break
 				-	If the object is still alive, the app should retrieve the data again from CoreData, and re-engage
 		-	Pending Downloads
 				-	Download operations should be resumed
 -	Test Connectivity:
 		-	Active uploads/downloads should get moved to the pendings queue
 		-	Right after connectivity gets re-acquired, pendings should be re-engaged
 -	Test backgrounding:
 		-	iOS shouldn't kill the app
 -	Test Downloads
 		-	If the object gets deleted before a download is complete, nothing should break
 		-	If a **new** change comes in (remote mTime > local mTime), any previous Upload/Download for the same entity should get cancelled
 		-	If the exact same file is already being downloaded (or was downloaded), don't do anything (hash verification)
 		-	If the exact same file is being uploaded (and SPHttpRequest delegate wasn't hit, thus, metadata didn't get updated), it shouldn't get redownloaded
		-	Test pending/active downloads queue
 		-	Null values shouldn't break anything
 -	Test Uploads
 		-	If there was any pending Upload/Download, it should get cancelled
 		-	If the exact NSData is already being uploaded for that object, don't do anything <<< verify that we can have the same data for multiple objects
 		-	Null values shouldn't break anything
		-	Test pending/active downloads queue
 */
	
//
//    [self createAndStartFarms];
//        
//    // Leader sends an object to followers
//    Farm *leader = [farms objectAtIndex:0];
//    [leader.simperium.binaryManager addDelegate:leader];
//    [self connectFarms];
//    [self waitFor:2];
//    [leader.simperium.binaryManager setupAuth:leader.simperium.user];
//    [self waitFor:2];
//    
//    SPBucket *leaderBucket = [leader.simperium bucketForName:@"Config"];
//    leader.config = [leaderBucket insertNewObject];
//    NSData *data = [self randomDataWithBytes:8096];
//    [leader.simperium addBinary:data toObject:leader.config bucketName:@"Config" attributeName:@"binaryFile"];
//    [leader.simperium save];
//    [self expectAdditions:1 deletions:0 changes:0 fromLeader:leader expectAcks:YES];
//    STAssertTrue([self waitForCompletion], @"timed out");
//    //    STAssertTrue([leader.config.warpSpeed isEqualToNumber: refWarpSpeed], @"");
//    
//    [self ensureFarmsEqual:farms entityName:@"Config"];
    
    NSLog(@"%@ end", self.name); 
}


@end
