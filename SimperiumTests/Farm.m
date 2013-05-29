//
//  Farm.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-10.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "Farm.h"
#import "TestParams.h"
#import "SPUser.h"

@implementation Farm
@synthesize simperium;
@synthesize config;
@synthesize token;
@synthesize done;
@synthesize expectedAcknowledgments;
@synthesize expectedAdditions;
@synthesize expectedChanges;
@synthesize expectedDeletions;
@synthesize expectedVersions;
@synthesize expectedIndexCompletions;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;


- (id)initWithToken:(NSString *)aToken bucketOverrides:(NSDictionary *)bucketOverrides label:(NSString *)label {
    if (self = [super init]) {
        done = NO;
        
        self.simperium = [[Simperium alloc] initWithRootViewController:nil];
        
        // Setting a label allows each Simperium instance to store user prefs under a different key
        // (be sure to do this before the call to clearLocalData)
        simperium.label = label;
        
        [simperium setAuthenticationEnabled:NO];
        [simperium setBucketOverrides:bucketOverrides];
        [simperium setVerboseLoggingEnabled:YES];
        simperium.useWebSockets = YES;
        self.token = aToken;
    }
    return self;
}

- (void)start {
    // JSON testing
    //[simperium startWithAppName:APP_ID APIKey:API_KEY];
    
    // Core Data testing
    [simperium startWithAppID:APP_ID APIKey:API_KEY model:[self managedObjectModel]
                      context:[self managedObjectContext] coordinator:[self persistentStoreCoordinator]];
    
    [simperium setAllBucketDelegates: self];
    
    // Some stuff is stored in user prefs, so be sure to remove it
    // (needs to be done after Simperium and its network managers have been started)
    //[simperium clearLocalData];
    
    simperium.user = [[SPUser alloc] initWithEmail:USERNAME token:token];
    for (NSString *bucketName in [simperium.bucketOverrides allKeys]) {
        [simperium bucketForName:bucketName].notifyWhileIndexing = YES;
    }
}

- (void)dealloc {
    [simperium signOutAndRemoveLocalData:YES];
    [simperium release];
    [config release];
    [super dealloc];
}

- (BOOL)waitForCompletion:(NSTimeInterval)timeoutSecs {
	NSDate	*timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeoutSecs];
    
	do {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
		if([timeoutDate timeIntervalSinceNow] < 0.0)
			break;
	} while (!done);
    
	return done;
}

- (BOOL)isDone {
    return expectedAcknowledgments == 0 && expectedChanges == 0 && expectedAdditions == 0 && expectedDeletions == 0
        && expectedVersions == 0 && expectedIndexCompletions == 0;
}

- (void)resetExpectations {
    self.expectedAcknowledgments = 0;
    self.expectedAdditions = 0;
    self.expectedChanges = 0;
    self.expectedDeletions = 0;
    self.expectedVersions = 0;
    self.expectedIndexCompletions = 0;
}

- (void)logUnfulfilledExpectations {
    if (![self isDone])
        NSLog(@"acks: %d changes: %d adds: %d dels: %d idxs: %d", expectedAcknowledgments, expectedChanges, expectedAdditions,
              expectedDeletions, expectedIndexCompletions);
}

- (void)connect {
    [simperium performSelector:@selector(startNetworkManagers)];
}

- (void)disconnect {
    [simperium performSelector:@selector(stopNetworkManagers)];
}

-(void)bucket:(SPBucket *)bucket didChangeObjectForKey:(NSString *)key forChangeType:(SPBucketChangeType)change {
    switch(change) {
        case SPBucketChangeAcknowledge:
            expectedAcknowledgments -= 1;
            break;
        case SPBucketChangeDelete:
            expectedDeletions -= 1;
            break;
        case SPBucketChangeInsert:
            expectedAdditions -= 1;
            break;
        case SPBucketChangeUpdate:
            expectedChanges -= 1;
    }
}

- (void)bucket:(SPBucket *)bucket willChangeObjectsForKeys:(NSSet *)keys {
    
}

- (void)bucketWillStartIndexing:(SPBucket *)bucket {
}

- (void)bucketDidFinishIndexing:(SPBucket *)bucket {
    NSLog(@"Simperium bucketDidFinishIndexing: %@", bucket.name);
    
    // These aren't always used in the tests, so only decrease it if it's been set
    if (expectedIndexCompletions > 0)
        expectedIndexCompletions -= 1;
}

- (void)bucketDidAcknowledgeDelete:(SPBucket *)bucket {
    expectedAcknowledgments -= 1;
}

- (void)bucket:(SPBucket *)bucket didReceiveObjectForKey:(NSString *)key version:(NSString *)version data:(NSDictionary *)data {
    expectedVersions -= 1;
}


#pragma mark - Manual Core Data stack

// This code for setting up a Core Data stack is taken directly from Apple's Core Data project template.

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil)
    {
        BOOL bChanged = [managedObjectContext hasChanges];
        if (bChanged && ![managedObjectContext save:&error])
        {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil)
    {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        __managedObjectContext = [[NSManagedObjectContext alloc] init];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return __managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil)
    {
        return __managedObjectModel;
    }
    __managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]] retain];   
    return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    // Use an in-memory store for testing
    if (!__persistentStoreCoordinator) {
        NSError *error = nil;
        __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        [__persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType 
                                                   configuration:nil URL:nil options:nil error:&error];
    }
    return __persistentStoreCoordinator;  
}

@end
