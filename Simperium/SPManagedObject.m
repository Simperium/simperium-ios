//
//  SPManagedObject.m
//
//  Created by Michael Johnston on 11-02-11.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SPManagedObject.h"
#import "SPCoreDataStorage.h"
#import "SPBucket+Internals.h"
#import "SPSchema.h"
#import "SPDiffer.h"
#import "SPMember.h"
#import "Simperium.h"
#import "SPGhost.h"
#import "JSONKit+Simperium.h"
#import "SPLogger.h"
#import <objc/runtime.h>



@implementation SPManagedObject

@synthesize ghost;
@synthesize updateWaiting;
@synthesize bucket = _bucket;
@dynamic simperiumKey;
@dynamic ghostData;

- (void)simperiumSetValue:(id)value forKey:(NSString *)key {
    [self setValue:value forKey:key];
}

- (id)simperiumValueForKey:(NSString *)key {
    return [self valueForKey:key];
}


- (void)configureBucket {
    
    // Get the MOC's Grandpa (writerContext)
    NSManagedObjectContext *writerManagedObjectContext = self.managedObjectContext;
    
    while (writerManagedObjectContext.parentContext) {
        writerManagedObjectContext = writerManagedObjectContext.parentContext;
    }

    // Check
    NSDictionary *bucketList = objc_getAssociatedObject(writerManagedObjectContext, SPCoreDataBucketListKey);
    
    if (!bucketList) {
        NSLog(@"Simperium error: bucket list not loaded. Ensure Simperium is started before any objects are fetched.");
    }

    _bucket = bucketList[self.entity.name];
}

- (SPBucket *)bucket
{
    if (!_bucket) {
        [self configureBucket];
    }
    return _bucket;
}

- (void)awakeFromFetch {
    [super awakeFromFetch];
    SPGhost *newGhost = [[SPGhost alloc] initFromDictionary: [self.ghostData sp_objectFromJSONString]];
    self.ghost = newGhost;
    [self.managedObjectContext userInfo];
	
    [self configureBucket];
}

- (void)awakeFromInsert {
    [super awakeFromInsert];
    [self configureBucket];
    
    // Determine if it was a local // remote insert, and call the right 'awake...' method
    if ([self.managedObjectContext.userInfo[SPCoreDataWorkerContext] boolValue]) {
        [self awakeFromRemoteInsert];
    } else {
        [self awakeFromLocalInsert];
    }
}

- (void)didTurnIntoFault {
    ghost = nil;
    [super didTurnIntoFault];
}

- (void)willSave {
    // When the entity is saved, check to see if its ghost has changed, in which case its data needs to be converted
    // to a string for storage
    if (ghost.needsSave) {
        // Careful not to use self.ghostData here, which would trigger KVC and cause strange things to happen (since willSave itself is related to Core Data's KVC triggerings). This manifested itself as an erroneous insertion notification being sent to fetchedResultsControllers after an object had been deleted. The underlying cause seemed to be that the deleted object sticks around as a fault, but probably shouldn't.
        NSString *ghostData = [[[ghost dictionary] sp_JSONString] copy];
        [self setPrimitiveValue:ghostData forKey:@"ghostData"];
        ghost.needsSave = NO;
    }
    [super willSave];
}

- (SPGhost *)ghost
{
    if (ghost == nil) {
        NSString *ghostData = [self ghostData];
        if (ghostData) {
            ghost = [[SPGhost alloc] initFromDictionary:[ghostData sp_objectFromJSONString]];
        } else {
            ghost = [[SPGhost alloc] initWithKey:self.simperiumKey memberData:nil];
        }
    }
    return ghost;
}

- (void)setGhostData:(NSString *)aString {
    // Core Data compliant way to update members
    [self willChangeValueForKey:@"ghostData"];
    // NSString implements NSCopying, so copy the attribute value
    NSString *newStr = [aString copy];
    [self setPrimitiveValue:newStr forKey:@"ghostData"]; // setPrimitiveContent will make it nil if the string is empty
    [self didChangeValueForKey:@"ghostData"];
}


- (NSString *)localID {
    NSManagedObjectID *key = [self objectID];
    if ([key isTemporaryID]) {
        return nil;
    }
    return [[key URIRepresentation] absoluteString];
}

- (void)loadMemberData:(NSDictionary *)memberData {    
    // Copy data for each member from the dictionary
    for (NSString *memberKey in [memberData allKeys]) {
        SPMember *member = [self.bucket.differ.schema memberForKey:memberKey];
        if (member) {
            id JSONValue = memberData[memberKey];
            [member setMemberValueFromJSONValue:JSONValue onParentObject:self];
        }
    }
}

- (void)willBeRead {
    // Bit of a hack to force fire the fault
    if ([self isFault]) {
        [self simperiumKey];
    }
}

- (NSDictionary *)dictionary {
    // Return a dictionary that contains member names as keys and actual member data as values
    // This can be used for diffing, serialization, networking, etc.
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    for (SPMember *member in [_bucket.differ.schema.members allValues]) {
        id data = [member JSONValueForMemberOnParentObject:self];
        if (data) dict[member.keyName] = data;
    }
    
    // Might be beneficial to eventually cache this and only update it when data has changed
    return dict;
}

- (NSString *)version {
    return ghost.version;
}

- (id)object {
    return self;
}

- (void)awakeFromLocalInsert {
    // Override me if needed!
}

- (void)awakeFromRemoteInsert {
    // Override me if needed!
}

@end


@implementation SPManagedObject (HappyInspector)

+ (BOOL)simperiumObjectExistsWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context
{
    if (!simperiumKey || simperiumKey.length == 0) return nil;
    NSFetchRequest *fetchRequest = [self fetchRequestForSimperiumObjectWithEntityName:entityName simperiumKey:simperiumKey managedObjectContext:context];
    return [context countForFetchRequest:fetchRequest error:NULL] != 0;
}
+ (SPManagedObject *)simperiumObjectWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context faults:(BOOL)allowFaults
{
    return [self simperiumObjectWithEntityName:entityName simperiumKey:simperiumKey managedObjectContext:context faults:allowFaults prefetchedRelationships:nil];
}
+ (SPManagedObject *)simperiumObjectWithEntityName:(NSString *)entityName simperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context faults:(BOOL)allowFaults prefetchedRelationships:(NSArray *)prefetchedRelationships
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
