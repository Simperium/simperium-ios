//
//  SPNetworkProvider.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPDiffable.h"

@class SPBucket;

@protocol SPNetworkProvider <NSObject>
-(void)start:(SPBucket *)bucket name:(NSString *)name;
-(void)stop:(SPBucket *)bucket;
-(void)resetBucketAndWait:(SPBucket *)bucket;
-(void)getLatestVersionsForBucket:(SPBucket *)bucket;
-(void)getVersions:(int)numVersions forObject:(id<SPDiffable>)object;
-(void)sendObjectDeletion:(id<SPDiffable>)object;
-(void)sendObjectChanges:(id<SPDiffable>)object;
-(void)shareObject:(id<SPDiffable>)object withEmail:(NSString *)email;
@end

