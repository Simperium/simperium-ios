//
//  SPEmbeddedManagedObject.m
//  Simperium
//
//  Created by Andrew Mackenzie-Ross on 12/08/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPEmbeddedManagedObject.h"
#import "NSString+Simperium.h"


@implementation SPEmbeddedManagedObject
@dynamic simperiumKey;

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	self.simperiumKey = [NSString sp_makeUUID];
}

+ (BOOL)simperiumObjectExistsWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context
{
    if (!simperiumKey || simperiumKey.length == 0) return nil;
    NSFetchRequest *fetchRequest = [self fetchRequestForSimperiumObjectWithEntityName:entityName simperiumKey:simperiumKey managedObjectContext:context];
    return [context countForFetchRequest:fetchRequest error:NULL] != 0;
}
+ (SPEmbeddedManagedObject *)simperiumObjectWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context faults:(BOOL)allowFaults
{
    return [self simperiumObjectWithEntityName:entityName simperiumKey:simperiumKey managedObjectContext:context faults:allowFaults prefetchedRelationships:nil];
}
+ (SPEmbeddedManagedObject *)simperiumObjectWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context faults:(BOOL)allowFaults prefetchedRelationships:(NSArray *)prefetchedRelationships
{
    if (!simperiumKey || simperiumKey.length == 0) return nil;
    NSFetchRequest *fetchRequest = [self fetchRequestForSimperiumObjectWithEntityName:entityName simperiumKey:simperiumKey managedObjectContext:context];
    [fetchRequest setReturnsObjectsAsFaults:allowFaults];
    [fetchRequest setRelationshipKeyPathsForPrefetching:prefetchedRelationships];
    
    NSError *error;
    NSArray *items = [context executeFetchRequest:fetchRequest error:&error];
    
    if ([items count] == 0)
        return nil;
    
    return [items objectAtIndex:0];
    
}

+ (NSFetchRequest *)fetchRequestForSimperiumObjectWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    [fetchRequest setEntity:entityDescription];
    [fetchRequest setFetchLimit:1];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"simperiumKey == %@", simperiumKey];
    [fetchRequest setPredicate:predicate];
    return fetchRequest;
}


@end
