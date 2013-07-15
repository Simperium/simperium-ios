//
//  Farm.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-10.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Simperium.h"
#import "Config.h"
#import "SPBucket.h"

@interface Farm : NSObject <SimperiumDelegate, SPBucketDelegate> {
    Simperium *simperium;
    Config *config;
    NSString *token;
    BOOL done;
    
    int expectedAcknowledgments;
    int expectedAdditions;
    int expectedDeletions;
    int expectedChanges;
    int expectedVersions;
    int expectedIndexCompletions;
}

@property (nonatomic, strong) Simperium *simperium;
@property (nonatomic, strong) Config *config;
@property (nonatomic, copy) NSString *token;
@property (nonatomic) BOOL done;
@property (nonatomic) int expectedAcknowledgments;
@property (nonatomic) int expectedAdditions;
@property (nonatomic) int expectedDeletions;
@property (nonatomic) int expectedChanges;
@property (nonatomic) int expectedVersions;
@property (nonatomic) int expectedIndexCompletions;
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

-(id)initWithToken:(NSString *)token bucketOverrides:(NSDictionary *)bucketOverrides label:(NSString *)label;
-(void)start;
-(void)connect;
-(void)disconnect;
-(BOOL)waitForCompletion:(NSTimeInterval)timeoutSecs;
-(BOOL)isDone;
-(void)resetExpectations;
-(void)logUnfulfilledExpectations;

@end

