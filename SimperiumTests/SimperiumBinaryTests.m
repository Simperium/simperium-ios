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
	
#warning TODO: Fill Me!
//	Test Cases
//		- Delete an object before download is complete
//		- What if a remote change comes in, while there was another download/upload?  >> CANCEL previous download/upload!
//		- What if a local change is performed while a download/upload was in progress?	>> CANCEL previous download/upload if any!!
//		- What if the exact same file is already being downloaded?
//		- What if a remote change comes in, and the object was locally changed but not saved?
//		- What if we set a NIL value?
//		- What if we set again the same NSData?. (Hash should be the equal)
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
