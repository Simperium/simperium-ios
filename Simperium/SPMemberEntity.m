//
//  SPMemberEntity.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPMemberEntity.h"
#import "SPManagedObject.h"
#import "SPBucket+Internals.h"
#import "SPRelationshipResolver.h"

@implementation SPMemberEntity

- (id)initFromDictionary:(NSDictionary *)dict {
    if (self = [super initFromDictionary:dict]) {
        self.entityName = [dict objectForKey:@"entityName"];
    }
    
    return self;
}

- (id)defaultValue {
	return nil;
}

- (id)simperiumKeyForObject:(id)value {
	return [value simperiumKey] ?: @"";
}

- (SPManagedObject *)objectForKey:(NSString *)key context:(NSManagedObjectContext *)context {
    // TODO: could possibly just request a fault?
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    fetchRequest.entity     = [NSEntityDescription entityForName:self.entityName inManagedObjectContext:context];
    fetchRequest.predicate  = [NSPredicate predicateWithFormat:@"simperiumKey == %@", key];
    
    NSError *error;
    NSArray *items = [context executeFetchRequest:fetchRequest error:&error];
    
    return [items firstObject];
}

- (id)getValueFromDictionary:(NSDictionary *)dict key:(NSString *)key object:(id<SPDiffable>)object {
    NSString *simperiumKey = dict[key];
    
    // With optional 1 to 1 relationships, there might not be an object
    if (!simperiumKey || simperiumKey.length == 0) {
        return nil;
    }
    
    SPManagedObject *managedObject = (SPManagedObject *)object;
    id value = [self objectForKey:simperiumKey context:managedObject.managedObjectContext];
    SPBucket *bucket = object.bucket;
    
    if (value == nil) {
        // The object isn't here YET...but it will be LATER
        // This is a convenient place to track references because it's guaranteed to be called from loadMemberData in
        // SPManagedObject when it arrives off the wire.
        NSString *fromKey = object.simperiumKey;
        dispatch_async(dispatch_get_main_queue(), ^{
            // Let Simperium store the reference so it can be properly resolved when the object gets synced
            [bucket.relationshipResolver setPendingRelationshipBetweenKey:fromKey
                                                            fromAttribute:self.keyName
                                                                 inBucket:bucket.name
                                                            withTargetKey:simperiumKey
                                                          andTargetBucket:self.entityName
                                                                  storage:bucket.storage];
        });
    }
    return value;
}

- (void)setValue:(id)value forKey:(NSString *)key inDictionary:(NSMutableDictionary *)dict {
    id convertedValue = [self simperiumKeyForObject: value];
    [dict setValue:convertedValue forKey:key];
}

- (NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue {
    NSString *otherKey = [self simperiumKeyForObject:otherValue];
    
	NSAssert([thisValue isKindOfClass:[SPManagedObject class]] && [otherValue isKindOfClass:[SPManagedObject class]],
			 @"Simperium error: couldn't diff objects because their classes weren't SPManagedObject");
    
    NSString *thisKey = [self simperiumKeyForObject:thisValue];
    
    // No change if the entity keys are equal
    if ([thisKey isEqualToString:otherKey]) {
        return @{ };
    }
    
	// Construct the diff in the expected format
	return @{
        OP_OP       : OP_REPLACE,
        OP_VALUE    : otherKey
    };
}

- (id)applyDiff:(id)thisValue otherValue:(id)otherValue {
	return otherValue;
}

@end
