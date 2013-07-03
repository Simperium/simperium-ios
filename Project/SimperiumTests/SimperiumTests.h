//
//  SimperiumTests.h
//  SimperiumTests
//
//  Created by Michael Johnston on 11-04-19.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <UIKit/UIKit.h>
#import "Simperium.h"
#import "TestParams.h"

@class Farm;

@interface SimperiumTests : SenTestCase<SimperiumDelegate> {
    NSArray *tests;
    NSMutableArray *farms;
    NSString *token;
    BOOL done;
    NSDictionary *overrides;
}

@property (copy) NSString *token;
@property (strong) NSDictionary *overrides;

- (NSDictionary *)bucketOverrides;
- (NSString *)uniqueBucketFor:(NSString *)entityName;
- (void)waitFor:(NSTimeInterval)seconds;
- (BOOL)farmsDone:(NSArray *)farmArray;
- (BOOL)waitForCompletion:(NSTimeInterval)timeoutSecs farmArray:(NSArray *)farmArray;
- (BOOL)waitForCompletion;
- (Farm *)createFarm:(NSString *)label;
- (void)ensureFarmsEqual: (NSArray *)farmArray entityName:(NSString *)entityName;
- (void)createFarms;
- (void)startFarms;
- (void)createAndStartFarms;
- (void)connectFarms;
- (void)disconnectFarms;
- (void)expectAdditions:(int)additions deletions:(int)deletions changes:(int)changes fromLeader:(Farm *)leader expectAcks:(BOOL)expectAcks;
- (void)resetExpectations:(NSArray *)farmArray;

@end
