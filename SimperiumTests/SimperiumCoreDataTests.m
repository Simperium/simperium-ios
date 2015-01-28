//
//  SimperiumCoreDataTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 7/20/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SimperiumTests.h"
#import "Farm.h"
#import "Config.h"
#import "NSString+Simperium.h"
#import "SPBucket+Internals.h"


@interface SimperiumCoreDataTests : SimperiumTests

@end


#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSUInteger const kObjectsCount = 10;
static NSTimeInterval const kLocalTestTimeout = 1;
static NSTimeInterval const kRemoteTestTimeout = 10;

static NSString* const kInsertedKey	= @"inserted";
static NSString* const kUpdatedKey = @"updated";
static NSString* const kRefreshedKey = @"refreshed";
static NSString* const kDeletedKey = @"deleted";


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SimperiumCoreDataTests ()
@property (nonatomic, strong, readwrite) NSManagedObjectContext*    writerContext;
@property (nonatomic, strong, readwrite) NSManagedObjectContext*    mainContext;
@property (nonatomic, strong, readwrite) NSMutableDictionary*       changesByContext;
@end


#pragma mark ====================================================================================
#pragma mark SimperiumCoreDataTests
#pragma mark ====================================================================================

@implementation SimperiumCoreDataTests

- (void)setUp {
	[super setUp];
	
	// Fire up Simperium
    [self createAndStartFarms];
    [self connectFarms];

	// Load the contexts
    Farm *leader            = [self.farms lastObject];
	self.writerContext      = leader.simperium.writerManagedObjectContext;
	self.mainContext        = leader.simperium.managedObjectContext;
	self.changesByContext   = [NSMutableDictionary dictionary];
	
	XCTAssert(self.mainContext.concurrencyType == NSMainQueueConcurrencyType,       @"CoreData mainContext Setup Error");
	XCTAssert(self.writerContext.concurrencyType == NSPrivateQueueConcurrencyType,	@"CoreData writerContext Setup Error");
}

- (void)tearDown {
	[super tearDown];
	
	// Cleanup
	self.writerContext = nil;
	self.mainContext = nil;
	self.changesByContext = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark ====================================================================================
#pragma mark Tests!
#pragma mark ====================================================================================

- (void)testWriterMOC {
    NSLog(@"%@ start", self.name);
	
	// Let's insert new objects
	for (NSInteger i = 0; ++i <= kObjectsCount; ) {
		Config* config = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:self.mainContext];
		config.warpSpeed = @( arc4random_uniform(UINT_MAX) );
	}
	
	// Listen to the follower MainMOC changes & WriterMOC save notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleContextNote:) name:NSManagedObjectContextDidSaveNotification object:self.writerContext];
	
	// Scotty, beam the changes down!
	XCTAssertTrue(self.mainContext.hasChanges, @"Main MOC should have changes");
    
    [self.writerContext performBlockAndWait:^{
        XCTAssertFalse(self.writerContext.hasChanges, @"Writer MOC should not have changes");
    }];
	
	NSError* error = nil;
	[self.mainContext save:&error];
	XCTAssertFalse(error, @"Error Saving mainContext");
	
	// The writer save is async, and automatic. Hold the runloop just a sec
	[self waitFor:kLocalTestTimeout];
	
	// The writerContext should have persisted the changes
	NSArray *savedChanges = [[self changesForContext:self.writerContext] objectForKey:kInsertedKey];
	
	XCTAssertTrue(savedChanges.count == kObjectsCount, @"Writer MOC failed to persist the inserted objects");
	
    NSLog(@"%@ end", self.name);
}



- (void)testBucketMechanism {
    NSLog(@"%@ start", self.name);
	
	[super waitFor:kLocalTestTimeout];
	
	NSManagedObjectContext* workerContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	NSManagedObjectContext* deepContext	= [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	
	workerContext.parentContext = self.mainContext;
	deepContext.parentContext = workerContext;
	
	// Let's insert new objects
	Config* mainConfig = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:self.mainContext];
	XCTAssert(mainConfig.bucket, @"The MainContext newObject's bucket should not be nil");
	
    [workerContext performBlockAndWait:^{
        Config* workerConfig = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:workerContext];
        XCTAssert(workerConfig.bucket, @"The WorkerContext newObject's bucket should not be nil");
    }];
	
    [deepContext performBlockAndWait:^{
        Config* deepCofig = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:deepContext];
        XCTAssertTrue(deepCofig.bucket, @"The DeepContext newObject's bucket should not be nil");
    }];
	
	[super waitFor:kLocalTestTimeout];
	
    NSLog(@"%@ end", self.name);
}



- (void)testNestedInsert {
    NSLog(@"%@ start", self.name);
	
	NSManagedObjectContext *workerContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	NSManagedObjectContext *deepContext	= [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	
	workerContext.parentContext = self.mainContext;
	deepContext.parentContext	= workerContext;
	
	[deepContext performBlockAndWait:^{
		
		// Insert an object into the last context of the chain
		Config* inserted = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:deepContext];
		XCTAssertNotNil(inserted, @"Error inserting object in child");
		XCTAssertTrue(deepContext.hasChanges, @"Error inserting into Deep Context");
        
        [workerContext performBlockAndWait:^{
            XCTAssertFalse(workerContext.hasChanges, @"Worker context shouldn't have changes");
        }];

		// Push the changes one level up (to the 'workerContext')
		NSError* error = nil;
		[deepContext save:&error];
		XCTAssertNil(error, @"Error saving deep context");
        
		[workerContext performBlockAndWait:^{
            XCTAssertTrue(workerContext.hasChanges, @"Worker context SHOULD have changes");
            
			// Push one level up (mainContext)
			NSError* error = nil;
			[workerContext save:&error];
			XCTAssertNil(error, @"Error saving worker context");
            
			// Finally, this will reach the writer
			[self.mainContext performBlockAndWait:^{
                
                XCTAssertTrue(self.mainContext.hasChanges, @"Main context SHOULD have changes");
                
				NSError* error = nil;
				[self.mainContext save:&error];
				XCTAssertNil(error, @"Error saving Main context");
				NSLog(@"%@ BLOCK end", self.name);
				
				[super waitFor:kLocalTestTimeout];
			}];
		}];
	}];
	
    NSLog(@"%@ end", self.name);
}

- (void)testRemoteCRUD {
    NSLog(@"%@ start", self.name);

	// We'll need a follower farm
    Farm *follower = [self createFarm:@"follower"];
    [follower start];
    [follower connect];
		
    [self waitFor:1.0];

	// Prepare everything we need
	NSManagedObjectContext *followerMainMOC	= follower.simperium.managedObjectContext;
		
	// Listen to the follower MainMOC changes & WriterMOC save notifications
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleContextNote:) name:NSManagedObjectContextObjectsDidChangeNotification object:followerMainMOC];
	
	
	// ====================================================================================
	// Insert Test
	//	-   If a "lead" Simperium client inserts objects, the "follower" should insert those
	//		objects into the writer + main Contexts
	// ====================================================================================
	//
	
	NSMutableSet* objects = [NSMutableSet set];
	for (NSInteger i = 0; ++i <= kObjectsCount; ) {
		Config* config = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:self.mainContext];
		[objects addObject:config];
	}
	
	// Verify that the objects make it to the Follower's writer & main MOC's
	NSError* error = nil;
	[self.mainContext save:&error];
	XCTAssertNil(error, @"Error saving Leader MOC");

	[self waitFor:kRemoteTestTimeout];

	NSArray *mainInserted = [[self changesForContext:followerMainMOC] objectForKey:kInsertedKey];
	XCTAssertTrue( (mainInserted.count == kObjectsCount), @"The follower's mainMOC didn't get the new objects");
	
	
	// ====================================================================================
	// Update Test
	//	-	If a "lead" Simperium client updates a set of objects, the "follower" should
	//		 update those objects in both the writer AND main Contexts
	// ====================================================================================
	//
	
	for (Config* config in objects) {
		config.warpSpeed = @(31337);
		config.shieldsUp = @(YES);
		config.shieldPercent = @(100);
		config.captainsLog = @"You damn dirty borgs!";
	}
	
	error = nil;
	[self.mainContext save:&error];
	XCTAssertNil(error, @"Error saving Main Context");
	
	[self waitFor:kRemoteTestTimeout];
	
	NSArray *mainRefreshed = [self changesForContext:followerMainMOC][kRefreshedKey];
	XCTAssertTrue( (mainRefreshed.count == objects.count), @"Error Updating Objects" );
	
	for (Config* config in mainRefreshed) {
		XCTAssertTrue([config.warpSpeed isEqual:@(31337)], @"Update Test Failed");
		XCTAssertTrue([config.shieldsUp isEqual:@(YES)],	@"Update Test Failed");
		XCTAssertTrue([config.shieldPercent isEqual:@(100)],	@"Update Test Failed");
		XCTAssertTrue([config.captainsLog isEqual:@"You damn dirty borgs!"], @"Update Test Failed");
	}
	
	
	// ====================================================================================
	// Delete Test
	//	-	If a "lead" Simperium client delets a set of objects, the "follower" should delete
	//		those objects from the writer AND main Contexts
	// ====================================================================================
	//
	
	for (Config* config in objects) {
		[self.mainContext deleteObject:config];
	}
	
	error = nil;
	[self.mainContext save:&error];
	XCTAssertNil(error, @"Error saving Leader MOC");
	
	[self waitFor:kRemoteTestTimeout];
	
	NSArray *mainDeleted = [[self changesForContext:followerMainMOC] objectForKey:kDeletedKey];
	XCTAssertTrue( (mainDeleted.count == kObjectsCount), @"The follower's mainMOC failed to delete objects");
		
    NSLog(@"%@ end", self.name);
}


#pragma mark ====================================================================================
#pragma mark Helpers
#pragma mark ====================================================================================

- (void)handleContextNote:(NSNotification*)note {
	NSValue* wrappedSender		 = [NSValue valueWithNonretainedObject:note.object];
	NSMutableDictionary* changes = self.changesByContext[wrappedSender];
	
	// First time?
	if (!changes) {
		changes	= [NSMutableDictionary dictionary];
		changes[kInsertedKey] = [NSMutableArray array];
		changes[kUpdatedKey] = [NSMutableArray array];
		changes[kDeletedKey] = [NSMutableArray array];
		changes[kRefreshedKey] = [NSMutableArray array];
		self.changesByContext[wrappedSender] = changes;
	}
	
	// Track everything
	NSDictionary* userInfo = note.userInfo;
	NSSet* receivedInserts = userInfo[kInsertedKey];
	NSSet* receivedUpdates = userInfo[kUpdatedKey];
	NSSet* receivedDeletions = userInfo[kDeletedKey];
	NSSet* receivedRefreshed = userInfo[kRefreshedKey];
    
	if (receivedInserts) {
		NSMutableArray* inserted = changes[kInsertedKey];
		[inserted addObjectsFromArray:[receivedInserts allObjects]];
	}

	if (receivedUpdates) {
		NSMutableArray* updated = changes[kUpdatedKey];
		[updated addObjectsFromArray:[receivedUpdates allObjects]];
	}
	
	if (receivedDeletions) {
		NSMutableArray* deleted = changes[kDeletedKey];
		[deleted addObjectsFromArray:[receivedDeletions allObjects]];
	}

    if (receivedRefreshed) {
        NSMutableArray* refreshed = changes[kRefreshedKey];
        [refreshed addObjectsFromArray:[receivedRefreshed allObjects]];
    }
}

- (NSDictionary*)changesForContext:(NSManagedObjectContext*)context {
	NSValue* wrappedContext = [NSValue valueWithNonretainedObject:context];
	return self.changesByContext[wrappedContext];
}

@end
