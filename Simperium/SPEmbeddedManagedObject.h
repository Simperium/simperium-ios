//
//  SPEmbeddedManagedObject.h
//  Simperium
//
//  Created by Andrew Mackenzie-Ross on 12/08/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface SPEmbeddedManagedObject : NSManagedObject

+ (BOOL)simperiumObjectExistsWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context;
+ (SPEmbeddedManagedObject *)simperiumObjectWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context faults:(BOOL)allowFaults;
+ (SPEmbeddedManagedObject *)simperiumObjectWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context faults:(BOOL)allowFaults prefetchedRelationships:(NSArray *)prefetchedRelationships;

@property (nonatomic, strong, readwrite) NSString *simperiumKey;

@end
