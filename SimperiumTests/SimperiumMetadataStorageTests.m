//
//  SimperiumMetadataStorageTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 9/12/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SimperiumMetadataStorageTests.h"
#import "SPMetadataStorage.h"
#import "NSString+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSUInteger const SPMetadataIterations = 100;


#pragma mark ====================================================================================
#pragma mark SimperiumMetadataStorageTests
#pragma mark ====================================================================================

@implementation SimperiumMetadataStorageTests

- (void)testInserts
{
	NSString *storageLabel = [NSString sp_makeUUID];
	SPMetadataStorage *storage = [[SPMetadataStorage alloc] initWithLabel:storageLabel];
	NSMutableDictionary *integrity = [NSMutableDictionary dictionary];
		
	// Test SetObject
	for(NSInteger i = 0; ++i <= SPMetadataIterations; )
	{
		NSDictionary *random = [self randomContentObject];
		NSString* key = [NSString stringWithFormat:@"%d", i];
		[storage setObject:random forKey:key];
		[integrity setObject:random forKey:key];
	}
	
	STAssertTrue( (storage.count == SPMetadataIterations), @"setObject Failed");
	
	// Test Hitting NSCache
	for(NSInteger i = 0; ++i <= SPMetadataIterations; )
	{
		NSString* key = [NSString stringWithFormat:@"%d", i];
		NSDictionary *retrieved = [storage objectForKey:key];
		NSDictionary *verify = [integrity objectForKey:key];
		
		STAssertEquals(retrieved, verify, @"Error retrieving object from NSCache");
	}

	// Test Hitting CoreData: Re-instantiate, so NSCache is empty
	storage = nil;
	storage = [[SPMetadataStorage alloc] initWithLabel:storageLabel];
	
	for(NSInteger i = 0; ++i <= SPMetadataIterations; )
	{
		NSString* key = [NSString stringWithFormat:@"%d", i];
		NSDictionary *retrieved = [storage objectForKey:key];
		NSDictionary *verify = [integrity objectForKey:key];
		
		STAssertTrue([retrieved isEqual:verify], @"Error retrieving object From CoreData");
	}
	
	// Cleanup
	[storage removeAllObjects];
	[integrity removeAllObjects];
	STAssertTrue( (storage.count == 0), @"RemoveAllObjects Failed");
}

- (void)testRemoval
{
	NSString *storageLabel = [NSString sp_makeUUID];
	SPMetadataStorage *storage = [[SPMetadataStorage alloc] initWithLabel:storageLabel];
		
	// Insert N objects
	NSMutableSet *allKeys = [NSMutableSet set];
	
	for(NSInteger i = 0; ++i <= SPMetadataIterations; )
	{
		NSDictionary *random = [self randomContentObject];
		NSString* key = [NSString stringWithFormat:@"%d", i];
		[storage setObject:random forKey:key];
		[allKeys addObject:key];
	}
	
	// Remove all of them
	for(NSString *key in allKeys)
	{
		id object = [storage objectForKey:key];
		STAssertNotNil(object, @"Error retrieving object");
		
		[storage removeObjectForKey:key];
		object = [storage objectForKey:key];
		STAssertNil(object, @"Error removing object");
	}
	
	// Make sure next time they'll ""stay removed""
	storage = [[SPMetadataStorage alloc] initWithLabel:storageLabel];
	
	for(NSString *key in allKeys)
	{
		id object = [storage objectForKey:key];
		STAssertNil(object, @"Zombie Objects Found!");
	}
	
	// Cleanup
	[allKeys removeAllObjects];
}

- (void)testNamespaces
{
	// Fresh Start
	NSString *firstLabel = [NSString sp_makeUUID];
	NSString *secondLabel = [NSString sp_makeUUID];
	SPMetadataStorage *firstStorage = [[SPMetadataStorage alloc] initWithLabel:firstLabel];
	SPMetadataStorage *secondStorage = [[SPMetadataStorage alloc] initWithLabel:secondLabel];
		
	// Insert in the first storage
	NSMutableSet *allKeys = [NSMutableSet set];
	
	for(NSInteger i = 0; ++i <= SPMetadataIterations; ) {
		NSDictionary *random = [self randomContentObject];
		NSString* key = [NSString stringWithFormat:@"%d", i];
		[firstStorage setObject:random forKey:key];
		[allKeys addObject:key];
	}
	
	// Verify that the second storage doesn't return anything for those keys
	for (NSString *key in allKeys) {
		id object = [secondStorage objectForKey:key];
		STAssertNil(object, @"Namespace Integrity Breach");
	}
	
	// Cleanup
	[firstStorage removeAllObjects];
	[secondStorage removeAllObjects];
	[allKeys removeAllObjects];
}


#pragma mark ====================================================================================
#pragma mark Helpers
#pragma mark ====================================================================================

- (NSDictionary*)randomContentObject
{
	NSMutableDictionary *random = [NSMutableDictionary dictionary];
	
	for(NSInteger i = 0; ++i <= SPMetadataIterations; ) {
		[random setObject:[NSString sp_makeUUID] forKey:[NSString sp_makeUUID]];
	}
	
	return random;
}

@end
