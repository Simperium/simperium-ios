//
//  SimperiumCoreDataTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 7/20/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SimperiumCoreDataTests.h"
#import "Farm.h"
#import "Config.h"
#import "NSString+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSUInteger const kObjectsCount = 10;
static NSTimeInterval const kLocalTestTimeout = 1;
static NSTimeInterval const kRemoteTestTimeout = 10;

static NSString* const kInsertedKey	= @"inserted";
static NSString* const kUpdatedKey = @"updated";
static NSString* const kDeletedKey = @"deleted";


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SimperiumCoreDataTests ()
@property (nonatomic, strong, readwrite) NSManagedObjectContext* writerContext;
@property (nonatomic, strong, readwrite) NSManagedObjectContext* mainContext;
@property (nonatomic, strong, readwrite) NSMutableDictionary* changesByContext;
@end


#pragma mark ====================================================================================
#pragma mark SimperiumCoreDataTests
#pragma mark ====================================================================================

@implementation SimperiumCoreDataTests

-(void)setUp {
		
	[super setUp];
	
	// Fire up Simperium
    [self createAndStartFarms];
    [self connectFarms];

	// Load the contexts
    Farm *leader = [farms lastObject];
	self.writerContext = leader.simperium.writerManagedObjectContext;
	self.mainContext = leader.simperium.managedObjectContext;
	self.changesByContext = [NSMutableDictionary dictionary];
	
	STAssertTrue((self.mainContext.concurrencyType == NSMainQueueConcurrencyType), @"CoreData mainContext Setup Error");
	STAssertTrue((self.writerContext.concurrencyType == NSPrivateQueueConcurrencyType),	@"CoreData writerContext Setup Error");
}

-(void)tearDown {
	
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

-(void)testWriterMOC {
	
    NSLog(@"%@ start", self.name);
	
	// Let's insert new objects
	for(NSInteger i = 0; ++i <= kObjectsCount; )
	{
		Config* config = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:self.mainContext];
		config.warpSpeed = @( arc4random_uniform(UINT_MAX) );
	}
	
	// Listen to the follower MainMOC changes & WriterMOC save notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleContextNote:) name:NSManagedObjectContextDidSaveNotification object:self.writerContext];
	
	// Scotty, beam the changes down!
	STAssertTrue(self.mainContext.hasChanges, @"Main MOC should have changes");
	STAssertFalse(self.writerContext.hasChanges, @"Writer MOC should not have changes");
	
	NSError* error = nil;
	[self.mainContext save:&error];
	STAssertFalse(error, @"Error Saving mainContext");
	
	// The writer save is async, and automatic. Hold the runloop just a sec
	[self waitFor:kLocalTestTimeout];
	
	// The writerContext should have persisted the changes
	NSArray *savedChanges = [[self changesForContext:self.writerContext] objectForKey:kInsertedKey];
	
	STAssertTrue( (savedChanges.count == kObjectsCount), @"Writer MOC failed to persist the inserted objects");
	
    NSLog(@"%@ end", self.name);
}



-(void)testBucketMechanism {
	
    NSLog(@"%@ start", self.name);
	
	NSManagedObjectContext* workerContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	NSManagedObjectContext* deepContext	= [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	
	workerContext.parentContext = self.mainContext;
	deepContext.parentContext = workerContext;
	
	// Let's insert new objects
	Config* config = nil;
	
	config = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:self.mainContext];
	STAssertTrue( (config.bucket != nil), @"The MainContext newObject's bucket should not be nil");
	
	config = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:workerContext];
	STAssertTrue( (config.bucket != nil), @"The WorkerContext newObject's bucket should not be nil");
	
	config = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:deepContext];
	STAssertTrue( (config.bucket != nil), @"The DeepContext newObject's bucket should not be nil");
	
    NSLog(@"%@ end", self.name);
}



-(void)testNestedInsert {
	
    NSLog(@"%@ start", self.name);
	
	NSManagedObjectContext *workerContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	NSManagedObjectContext *deepContext	= [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	
	workerContext.parentContext = self.mainContext;
	deepContext.parentContext	= workerContext;
	
	[deepContext performBlockAndWait:^{
		
		// Insert an object into the last context of the chain
		Config* inserted = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:deepContext];
		STAssertNotNil(inserted, @"Error inserting object in child");
		STAssertTrue(  (deepContext.hasChanges), @"Error inserting into Deep Context");
		STAssertFalse( (workerContext.hasChanges), @"Worker context shouldn't have changes");

		// Push the changes one level up (to the 'workerContext')
		NSError* error = nil;
		[deepContext save:&error];
		STAssertNil(error, @"Error saving deep context");
		STAssertTrue( (workerContext.hasChanges), @"Worker context SHOULD have changes");
		
		[workerContext performBlockAndWait:^{
		
			// Push one level up (mainContext)
			NSError* error = nil;
			[workerContext save:&error];
			STAssertNil(error, @"Error saving worker context");
			STAssertTrue( (self.mainContext.hasChanges), @"Main context SHOULD have changes");
			
			// Finally, this will reach the writer
			[self.mainContext performBlockAndWait:^{
				
				NSError* error = nil;
				[self.mainContext save:&error];
				STAssertNil(error, @"Error saving Main context");
			}];
		}];
	}];
	
    NSLog(@"%@ end", self.name);
}



-(void)testRemoteCRUD {
	
    NSLog(@"%@ start", self.name);

	// We'll need a follower farm
    Farm *follower = [self createFarm:@"follower"];
    [follower start];
    [follower connect];
		
    [self waitFor:1.0];

	// Prepare everything we need
	NSManagedObjectContext *followerMainMOC	= follower.simperium.managedObjectContext;
	NSManagedObjectContext *followerWriterMOC = follower.simperium.writerManagedObjectContext;
		
	// Listen to the follower MainMOC changes & WriterMOC save notifications
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleContextNote:) name:NSManagedObjectContextObjectsDidChangeNotification object:followerMainMOC];
	[nc addObserver:self selector:@selector(handleContextNote:) name:NSManagedObjectContextDidSaveNotification object:followerWriterMOC];
	
	
	// ====================================================================================
	// Insert Test
	//	-   If a "lead" Simperium client inserts objects, the "follower" should insert those
	//		objects into the writer + main Contexts
	// ====================================================================================
	//
	
	NSMutableSet* objects = [NSMutableSet set];
	for(NSInteger i = 0; ++i <= kObjectsCount; )
	{
		Config* config = [NSEntityDescription insertNewObjectForEntityForName:@"Config" inManagedObjectContext:self.mainContext];
		[objects addObject:config];
	}
	
	// Verify that the objects make it to the Follower's writer & main MOC's
	NSError* error = nil;
	[self.mainContext save:&error];
	STAssertNil(error, @"Error saving Leader MOC");

	[self waitFor:kRemoteTestTimeout];

	NSArray *mainInserted = [[self changesForContext:followerMainMOC] objectForKey:kInsertedKey];
	NSArray *writerInserted = [[self changesForContext:followerWriterMOC] objectForKey:kInsertedKey];
	
	STAssertTrue( (mainInserted.count == kObjectsCount), @"The follower's mainMOC didn't get the new objects");
	STAssertTrue( (writerInserted.count == kObjectsCount), @"The follower's writerMOC didn't persist the new objects");
	
	
	// ====================================================================================
	// Update Test
	//	-	If a "lead" Simperium client updates a set of objects, the "follower" should
	//		 update those objects in both the writer AND main Contexts
	// ====================================================================================
	//
	
	for(Config* config in objects)
	{
		config.warpSpeed = @(31337);
		config.shieldsUp = @(YES);
		config.shieldPercent = @(100);
		config.captainsLog = @"You damn dirty borgs!";
	}
	
	error = nil;
	[self.mainContext save:&error];
	STAssertNil(error, @"Error saving Main Context");
	
	[self waitFor:kRemoteTestTimeout];
	
	NSArray *mainUpdated = [self changesForContext:followerWriterMOC][kUpdatedKey];
	STAssertTrue( (mainUpdated.count == objects.count), @"Error Updating Objects" );
	
	for(Config* config in mainUpdated)
	{
		STAssertTrue([config.warpSpeed isEqual:@(31337)], @"Update Test Failed");
		STAssertTrue([config.shieldsUp isEqual:@(YES)],	@"Update Test Failed");
		STAssertTrue([config.shieldPercent isEqual:@(100)],	@"Update Test Failed");
		STAssertTrue([config.captainsLog isEqual:@"You damn dirty borgs!"], @"Update Test Failed");
	}
	
	
	// ====================================================================================
	// Delete Test
	//	-	If a "lead" Simperium client delets a set of objects, the "follower" should delete
	//		those objects from the writer AND main Contexts
	// ====================================================================================
	//
	
	for(Config* config in objects)
	{
		[self.mainContext deleteObject:config];
	}
	
	error = nil;
	[self.mainContext save:&error];
	STAssertNil(error, @"Error saving Leader MOC");
	
	[self waitFor:kRemoteTestTimeout];
	
	NSArray *mainDeleted = [[self changesForContext:followerMainMOC] objectForKey:kDeletedKey];
	NSArray *writerDeleted = [[self changesForContext:followerWriterMOC] objectForKey:kDeletedKey];
	
	STAssertTrue( (mainDeleted.count == kObjectsCount), @"The follower's mainMOC failed to delete objects");
	STAssertTrue( (writerDeleted.count == kObjectsCount), @"The follower's writerMOC failed to delete objects");
		
    NSLog(@"%@ end", self.name);
}


#pragma mark ====================================================================================
#pragma mark Helpers
#pragma mark ====================================================================================

-(void)handleContextNote:(NSNotification*)note
{
	NSValue* wrappedSender		 = [NSValue valueWithNonretainedObject:note.object];
	NSMutableDictionary* changes = self.changesByContext[wrappedSender];
	
	// First time?
	if(!changes)
	{
		changes	= [NSMutableDictionary dictionary];
		changes[kInsertedKey] = [NSMutableArray array];
		changes[kUpdatedKey] = [NSMutableArray array];
		changes[kDeletedKey] = [NSMutableArray array];
		self.changesByContext[wrappedSender] = changes;
	}
	
	// Track everything
	NSDictionary* userInfo = note.userInfo;
	NSSet* receivedInserts = userInfo[kInsertedKey];
	NSSet* receivedUpdates = userInfo[kUpdatedKey];
	NSSet* receivedDeletions = userInfo[kDeletedKey];
	
	if(receivedInserts)
	{
		NSMutableArray* inserted = changes[kInsertedKey];
		[inserted addObjectsFromArray:[receivedInserts allObjects]];
	}

	if(receivedUpdates)
	{
		NSMutableArray* updated = changes[kUpdatedKey];
		[updated addObjectsFromArray:[receivedUpdates allObjects]];
	}
	
	if(receivedDeletions)
	{
		NSMutableArray* deleted = changes[kDeletedKey];
		[deleted addObjectsFromArray:[receivedDeletions allObjects]];
	}
}

-(NSDictionary*)changesForContext:(NSManagedObjectContext*)context
{
	NSValue* wrappedContext = [NSValue valueWithNonretainedObject:context];
	return self.changesByContext[wrappedContext];
}

@end
