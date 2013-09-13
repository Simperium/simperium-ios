//
//  SimperiumDictionaryStorageTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 9/12/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SimperiumDictionaryStorageTests.h"
#import "SPDictionaryStorage.h"
#import "NSString+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSUInteger const SPMetadataIterations = 100;


#pragma mark ====================================================================================
#pragma mark SimperiumMetadataStorageTests
#pragma mark ====================================================================================

@implementation SimperiumDictionaryStorageTests

- (void)testInserts
{
	NSString *storageLabel = [NSString sp_makeUUID];
	SPDictionaryStorage *storage = [[SPDictionaryStorage alloc] initWithLabel:storageLabel];
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
		STAssertTrue([storage containsObjectForKey:key], @"Error in containsObjectForKey");
	}

	// Test Hitting CoreData: Re-instantiate, so NSCache is empty
	storage = nil;
	storage = [[SPDictionaryStorage alloc] initWithLabel:storageLabel];
	
	for(NSInteger i = 0; ++i <= SPMetadataIterations; )
	{
		NSString* key = [NSString stringWithFormat:@"%d", i];
		NSDictionary *retrieved = [storage objectForKey:key];
		NSDictionary *verify = [integrity objectForKey:key];
		
		STAssertTrue([retrieved isEqual:verify], @"Error retrieving object From CoreData");
		STAssertTrue([storage containsObjectForKey:key], @"Error in containsObjectForKey");
	}
	
	// Cleanup
	[storage removeAllObjects];
	[integrity removeAllObjects];
	STAssertTrue( (storage.count == 0), @"RemoveAllObjects Failed");
}

- (void)testRemoval
{
	NSString *storageLabel = [NSString sp_makeUUID];
	SPDictionaryStorage *storage = [[SPDictionaryStorage alloc] initWithLabel:storageLabel];
		
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
		STAssertFalse([storage containsObjectForKey:key], @"Error in containsObjectForKey");
	}
	
	// Make sure next time they'll ""stay removed""
	storage = [[SPDictionaryStorage alloc] initWithLabel:storageLabel];
	
	for(NSString *key in allKeys)
	{
		id object = [storage objectForKey:key];
		STAssertNil(object, @"Zombie Objects Found!");
		STAssertFalse([storage containsObjectForKey:key], @"Error in containsObjectForKey");
	}
	
	// Cleanup
	[allKeys removeAllObjects];
}

- (void)testNamespaces
{
	// Fresh Start
	NSString *firstLabel = [NSString sp_makeUUID];
	NSString *secondLabel = [NSString sp_makeUUID];
	SPDictionaryStorage *firstStorage = [[SPDictionaryStorage alloc] initWithLabel:firstLabel];
	SPDictionaryStorage *secondStorage = [[SPDictionaryStorage alloc] initWithLabel:secondLabel];
		
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
