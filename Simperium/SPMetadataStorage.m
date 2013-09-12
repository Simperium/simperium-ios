//
//  SPMetadataStorage.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 9/12/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPMetadataStorage.h"
#import <CoreData/CoreData.h>



#pragma mark ====================================================================================
#pragma mark Private Internal Class
#pragma mark ====================================================================================

@interface SPChange : NSManagedObject
@property (nonatomic, strong, readwrite) NSString *key;
@property (nonatomic, strong, readwrite) NSData *value;
@end

@implementation SPChange
@dynamic key;
@dynamic value;

-(void)archiveValueWithObject:(id)object
{
	self.value = [NSKeyedArchiver archivedDataWithRootObject:object];
}

-(id)unarchiveValue
{
	return [NSKeyedUnarchiver unarchiveObjectWithData:self.value];
}

@end


#pragma mark ====================================================================================
#pragma mark Private Methods
#pragma mark ====================================================================================

@interface SPMetadataStorage ()
@property (nonatomic, strong, readwrite) NSString *label;
@property (nonatomic, strong, readwrite) NSCache *cache;
@property (nonatomic, strong, readwrite) NSManagedObjectContext* managedObjectContext;
@property (nonatomic, strong, readwrite) NSManagedObjectModel* managedObjectModel;
@property (nonatomic, strong, readwrite) NSPersistentStoreCoordinator* persistentStoreCoordinator;
- (NSURL*)storeURL;
- (void)saveContext;
@end


#pragma mark ====================================================================================
#pragma mark SPMetadataStorage
#pragma mark ====================================================================================

@implementation SPMetadataStorage

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
		value = [[results firstObject] unarchiveValue];
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
		return;
	}
	
	// Remove any previous value
	[self removeObjectForKey:aKey];

	// Upsert Operation
	[self.managedObjectContext performBlockAndWait:^{
		
		NSError *error = nil;
		NSArray *results = [self.managedObjectContext executeFetchRequest:[self requestForEntityWithKey:aKey] error:&error];
		NSAssert(results.count <= 1, @"ERROR: SPMetadataStorage has multiple entities with the same key");
		
		SPChange *change = (SPChange *)[results firstObject];
		
		if(change) {
			[change archiveValueWithObject:anObject];
		} else {
			change = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([SPChange class]) inManagedObjectContext:self.managedObjectContext];
			[change setKey:aKey];
			[change archiveValueWithObject:anObject];
		}
	}];
	
	// Persist & Update the cache
	[self saveContext];
	[self.cache setObject:anObject forKey:aKey];
}

- (void)removeObjectForKey:(id)aKey
{
	if(aKey == nil) {
		return;
	}
	
	[self.managedObjectContext performBlockAndWait:^{
		
		// Load the objectID
		NSFetchRequest *request = [self requestForEntityWithKey:aKey];
		[request setIncludesPropertyValues:NO];
		
		NSError *error = nil;
		NSArray *results = [self.managedObjectContext executeFetchRequest:request error:&error];
		
		// Once there, delete
		SPChange *change = [results firstObject];
		if(change) {
			[self.managedObjectContext deleteObject:change];
		}
	}];
	
	// Persist & Update the cache
	[self saveContext];
	[self.cache removeObjectForKey:aKey];
}

- (void)removeAllObjects
{
	// Remove from CoreData
	[self.managedObjectContext performBlockAndWait:^{
		
		// Fetch the objectID's
		NSFetchRequest *fetchRequest = [self requestForEntity];
		[fetchRequest setIncludesPropertyValues:NO];

		NSError *error = nil;
		NSArray *allObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
		
		// Delete Everything
		for(NSManagedObject *object in allObjects) {
			[self.managedObjectContext deleteObject:object];
		}
	}];
	
	// Persist & Update the cache
	[self saveContext];
	[self.cache removeAllObjects];
}


#pragma mark - Core Data Stack

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
	
	// SPChange Entity
	NSString* entityName = NSStringFromClass([SPChange class]);
	NSEntityDescription *entity = [[NSEntityDescription alloc] init];
	[entity setName:entityName];
	[entity setManagedObjectClassName:entityName];
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
	return [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([SPChange class])];
}

- (NSFetchRequest*)requestForEntityWithKey:(id)aKey
{
	NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([SPChange class])];
	request.predicate = [NSPredicate predicateWithFormat:@"key == %@", aKey];
	
	return request;
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
