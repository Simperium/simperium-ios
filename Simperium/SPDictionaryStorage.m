//
//  SPDictionaryStorage.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 9/12/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPDictionaryStorage.h"
#import <CoreData/CoreData.h>



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString *SPDictionaryEntityName		= @"SPDictionaryEntityName";
static NSString *SPDictionaryEntityValue	= @"value";
static NSString *SPDictionaryEntityKey		= @"key";


#pragma mark ====================================================================================
#pragma mark Private Methods
#pragma mark ====================================================================================

@interface SPDictionaryStorage ()
@property (nonatomic, strong, readwrite) NSString *label;
@property (nonatomic, strong, readwrite) NSCache *cache;
@property (nonatomic, strong, readwrite) NSManagedObjectContext* managedObjectContext;
@property (nonatomic, strong, readwrite) NSManagedObjectModel* managedObjectModel;
@property (nonatomic, strong, readwrite) NSPersistentStoreCoordinator* persistentStoreCoordinator;
- (NSURL*)storeURL;
- (void)saveContext;
@end


#pragma mark ====================================================================================
#pragma mark SPDictionaryStorage
#pragma mark ====================================================================================

@implementation SPDictionaryStorage

- (id)initWithLabel:(NSString *)label
{
	if((self = [super init]))
	{
		self.label = label;
		self.cache = [[NSCache alloc] init];
	}
	
	return self;
}

- (NSInteger)count
{
	__block NSUInteger count = 0;
	
	[self.managedObjectContext performBlockAndWait:^() {
		NSError *error;
		count = [self.managedObjectContext countForFetchRequest:[self requestForEntity] error:&error];
	}];
	
	return count;
}

- (BOOL)containsObjectForKey:(id)aKey
{
	// Failsafe
	if(aKey == nil) {
		return false;
	}
	
	// Do we have a cache hit?
	__block BOOL exists = [self.cache objectForKey:aKey];
	if(exists) {
		return exists;
	}
	
	// Fault to Core Data
	[self.managedObjectContext performBlockAndWait:^{
		NSError *error = nil;
		exists = ([self.managedObjectContext countForFetchRequest:[self requestForEntityWithKey:aKey] error:&error] > 0);
	}];
	
	// Done
	return exists;
}

- (id)objectForKey:(id)aKey
{
	// Failsafe
	if(aKey == nil) {
		return nil;
	}

	// Do we have a cache hit?
	__block id value = [self.cache objectForKey:aKey];
	if(value) {
		return value;
	}
	
	// Fault to Core Data
	[self.managedObjectContext performBlockAndWait:^{
		NSError *error = nil;
		NSArray *results = [self.managedObjectContext executeFetchRequest:[self requestForEntityWithKey:aKey] error:&error];
		NSManagedObject *object = [results firstObject];
		
		// Unarchive
		id archivedValue = [object valueForKey:SPDictionaryEntityValue];
		if(archivedValue) {
			value = [NSKeyedUnarchiver unarchiveObjectWithData:archivedValue];
		}
	}];
	
	// Cache
	if(value) {
		[self.cache setObject:value forKey:aKey];
	}
	
	// Done
	return value;
}

- (void)setObject:(id)anObject forKey:(id)aKey
{
	// Failsafe
	if(anObject == nil) {
		[self removeObjectForKey:aKey];
		return;
	}

	[self.managedObjectContext performBlock:^{
		
		NSError *error = nil;
		NSArray *results = [self.managedObjectContext executeFetchRequest:[self requestForEntityWithKey:aKey] error:&error];
		NSAssert(results.count <= 1, @"ERROR: SPMetadataStorage has multiple entities with the same key");
		
		// Wrap up the value
		id archivedValue = [NSKeyedArchiver archivedDataWithRootObject:anObject];
		
		// Upsert
		NSManagedObject *change = (NSManagedObject *)[results firstObject];
				
		if(change) {
			[change setValue:archivedValue forKey:SPDictionaryEntityValue];
		} else {
			change = [NSEntityDescription insertNewObjectForEntityForName:SPDictionaryEntityName inManagedObjectContext:self.managedObjectContext];
			[change setValue:aKey forKey:SPDictionaryEntityKey];
			[change setValue:archivedValue forKey:SPDictionaryEntityValue];
		}
		
		// Save
		[self.managedObjectContext save:&error];
	}];
	
	// Persist & Update the cache
	[self.cache setObject:anObject forKey:aKey];
}

- (NSArray*)allKeys
{
	return [self loadObjectsProperty:SPDictionaryEntityKey];
}

- (NSArray*)allValues
{
	return [self loadObjectsProperty:SPDictionaryEntityValue];
}

- (void)removeObjectForKey:(id)aKey
{
	if(aKey == nil) {
		return;
	}
	
	[self.managedObjectContext performBlock:^{
		
		// Load the objectID
		NSFetchRequest *request = [self requestForEntityWithKey:aKey];
		[request setIncludesPropertyValues:NO];
		
		NSError *error = nil;
		NSArray *results = [self.managedObjectContext executeFetchRequest:request error:&error];
		
		// Once there, delete
		NSManagedObject *change = [results firstObject];
		if(change) {
			[self.managedObjectContext deleteObject:change];
			[self.managedObjectContext save:&error];
		}
	}];
	
	// Persist & Update the cache
	[self.cache removeObjectForKey:aKey];
}

- (void)removeAllObjects
{
	// Remove from CoreData
	[self.managedObjectContext performBlock:^{
		
		// Fetch the objectID's
		NSFetchRequest *fetchRequest = [self requestForEntity];
		[fetchRequest setIncludesPropertyValues:NO];

		NSError *error = nil;
		NSArray *allObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
		
		// Delete Everything
		for(NSManagedObject *object in allObjects) {
			[self.managedObjectContext deleteObject:object];
		}
		
		[self.managedObjectContext save:&error];
	}];
	
	// Persist & Update the cache
	[self.cache removeAllObjects];
}


#pragma mark ====================================================================================
#pragma mark Core Data Stack
#pragma mark ====================================================================================

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil)
	{
        return _managedObjectModel;
    }
	
	// Dynamic Attributes
	NSAttributeDescription *keyAttribute = [[NSAttributeDescription alloc] init];
	[keyAttribute setName:@"key"];
	[keyAttribute setAttributeType:NSStringAttributeType];
	[keyAttribute setOptional:NO];
	[keyAttribute setIndexed:YES];
	
	NSAttributeDescription *valueAttribute = [[NSAttributeDescription alloc] init];
	[valueAttribute setName:@"value"];
	[valueAttribute setAttributeType:NSBinaryDataAttributeType];
	[valueAttribute setOptional:NO];
	[valueAttribute setAllowsExternalBinaryDataStorage:YES];
	
	// SPMetadata Entity
	NSEntityDescription *entity = [[NSEntityDescription alloc] init];
	[entity setName:SPDictionaryEntityName];
	[entity setManagedObjectClassName:NSStringFromClass([NSManagedObject class])];
	[entity setProperties:@[keyAttribute, valueAttribute] ];
	
	// Done!
	NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
	[model setEntities:@[entity]];
	
	_managedObjectModel = model;
	
	return _managedObjectModel;
}

- (NSManagedObjectContext*)managedObjectContext
{
    if (_managedObjectContext != nil)
	{
        return _managedObjectContext;
    }
	
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	_managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
    return _managedObjectContext;
}


- (NSPersistentStoreCoordinator*)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil)
	{
        return _persistentStoreCoordinator;
    }
    
    NSError* error	= nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self.storeURL options:nil error:&error])
	{
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


#pragma mark ====================================================================================
#pragma mark Helpers
#pragma mark ====================================================================================

- (NSURL*)storeURL
{
	NSURL* documentsPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
	NSString* filename = [NSString stringWithFormat:@"SPChanges-%@.sqlite", self.label];
	return [documentsPath URLByAppendingPathComponent:filename];
}

- (NSFetchRequest*)requestForEntity
{
	return [NSFetchRequest fetchRequestWithEntityName:SPDictionaryEntityName];
}

- (NSFetchRequest*)requestForEntityWithKey:(id)aKey
{
	NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:SPDictionaryEntityName];
	request.predicate = [NSPredicate predicateWithFormat:@"key == %@", aKey];
	
	return request;
}

- (NSArray*)loadObjectsProperty:(NSString*)property
{
	NSMutableArray *keys = [NSMutableArray array];
	
	// Remove from CoreData
	[self.managedObjectContext performBlockAndWait:^{
		
		// Fetch the objectID's
		NSFetchRequest *fetchRequest = [self requestForEntity];
		[fetchRequest setIncludesPropertyValues:NO];
		
		NSError *error = nil;
		NSArray *allObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
		
		// Load properties
		for(NSManagedObject *change in allObjects) {
			id value = [change valueForKey:property];
			if(value) {
				[keys addObject:value];
			}
		}
	}];
	
	return keys;
}

- (void)saveContext
{
    if (self.managedObjectContext == nil)
	{
		return;
	}
	
	[self.managedObjectContext performBlock:^{
		
		NSError* error = nil;
		if ([self.managedObjectContext hasChanges] && ![self.managedObjectContext save:&error])
		{
			NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
			abort();
		}
	}];
}

@end
