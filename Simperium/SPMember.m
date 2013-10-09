//
//  SPMember.m
//  Simperium
//
//  Created by Michael Johnston on 11-02-12.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "Simperium.h"
#import "SPMember.h"
#import "SPEmbeddedManagedObject.h"
#import "SPBucket.h"
#import "SPRelationshipResolver.h"
#import "JSONKit+Simperium.h"
#import "NSString+Simperium.h"
#import "NSData+Simperium.h"

// Operations used for diff and transform
NSString * const OP_OP				= @"o";
NSString * const OP_VALUE			= @"v";
NSString * const OP_REPLACE			= @"r";
NSString * const OP_LIST_INSERT		= @"+";
NSString * const OP_LIST_DELETE		= @"-";
NSString * const OP_OBJECT_ADD		= @"+";
NSString * const OP_OBJECT_REMOVE	= @"-";
NSString * const OP_INTEGER			= @"I";
NSString * const OP_LIST			= @"L";
NSString * const OP_LIST_DMP		= @"dL";
NSString * const OP_OBJECT			= @"O";
NSString * const OP_STRING			= @"d";

NSString * const SPMemberDefinitionKeyNameKey = @"name";
NSString * const SPMemberDefinitionTypeKey = @"type";
NSString * const SPMemberDefinitionCustomOperationKey = @"otype";
NSString * const SPMemberDefinitionCustomJSONValueTransformerNameKey = @"jsonTransformer";
NSString * const SPMemberDefinitionMembersKey = @"members";
NSString * const SPMemberDefinitionEntityNameKey = @"entityName";
NSString * const SPMemberDefinitionListMemberKey = @"listMember";
NSString * const SPMemberDefinitionInverseKeyNameKey = @"inverseName";

static NSString * const SPPolicyItemKey = @"item";
static NSString * const SPPolicyAttributesKey = @"attributes";
static NSString * const SPOperationTypeKey = @"otype";


@interface SPMember()
{
    NSDictionary *_dictionaryForInitializer;
    NSMutableDictionary *_policy;
}
@property (nonatomic, copy, readonly) NSString *operationType;
@property (nonatomic, copy, readonly) NSValueTransformer *JSONValueTransformer;


@end

@implementation SPMember
@synthesize policy = _policy;



// Maps primitive type strings to base member classes
+ (SPMemberType)membeTypeForStringType:(NSString *)type
{
	if ([type isEqualToString:@"text"])
		return SPMemberTypeText;
	else if ([type isEqualToString:@"int"])
        return SPMemberTypeNumber; 
    else if ([type isEqualToString:@"boolean"])
        return SPMemberTypeBoolean;
	else if ([type isEqualToString:@"date"])
		return SPMemberTypeDate;
    else if ([type isEqualToString:@"entity"])
        return SPMemberTypeRelatedEntity;
    else if ([type isEqualToString:@"double"])
        return SPMemberTypeNumber;
    else if ([type isEqualToString:@"binary"])
        return SPMemberTypeBinary;
    else if ([type isEqualToString:@"list"])
        return SPMemberTypeList;
    else if ([type isEqualToString:@"transformable"])
        return SPMemberTypeTransformable;
	else if ([type isEqual:@"object"])
		return SPMemberTypeEmbeddedRelatedEntity;
	[NSException raise:NSInternalInconsistencyException format:@"Simperium member not available for type %@",type];
	return nil;
}

- (void)applyBucketPolicy:(NSDictionary *)bucketPolicy
{
    // TODO: implement
}

- (NSDictionary *)policy
{
    if (_policy) {
        _policy = [[NSMutableDictionary alloc] init];
        if (self.type == SPMemberTypeTransformable) _policy[SPPolicyAttributesKey] = OP_REPLACE;
        if (_operationType) _policy[SPPolicyAttributesKey] = _operationType;
        if (self.type == SPMemberTypeEmbeddedRelatedEntity) {
            for (SPMember *member in self.embeddedMembers) {
                
            }
        }

    }
    // TODO: implement so that tranformables do replace by default otherwise they'll just stringdiff
    return _policy;
}

-(id)initFromDictionary:(NSDictionary *)dict
{
	if ((self = [self init])) {
        _dictionaryForInitializer = dict;
		_keyName = [dict[SPMemberDefinitionKeyNameKey] copy];
		_operationType = [dict[SPMemberDefinitionCustomOperationKey] copy];
        _type = [[self class] membeTypeForStringType:dict[SPMemberDefinitionTypeKey]];
        
        NSString *JSONValueTransformerName = [dict[SPMemberDefinitionCustomJSONValueTransformerNameKey] copy];
        if (JSONValueTransformerName) {
            _JSONValueTransformer = [NSValueTransformer valueTransformerForName:JSONValueTransformerName];
            if (!_JSONValueTransformer || ![[_JSONValueTransformer class] allowsReverseTransformation]) [NSException raise:NSInternalInconsistencyException format:@"Unable to load reversible transformer with name %@",JSONValueTransformerName];
        }
        
        if (_type == SPMemberTypeEmbeddedRelatedEntity || _type == SPMemberTypeRelatedEntity) {
            _entityName = [dict[SPMemberDefinitionEntityNameKey] copy];
            if (_type == SPMemberTypeEmbeddedRelatedEntity) {
                NSMutableArray *members = [[NSMutableArray alloc] init];
                for (NSDictionary *memberDefintion in dict[SPMemberDefinitionMembersKey]) {
                    [members addObject:[[SPMember alloc] initFromDictionary:memberDefintion]];
                }
                _embeddedMembers = members;
                _inverseKeyName = [dict[SPMemberDefinitionInverseKeyNameKey] copy];
            }
        }
        if (_type == SPMemberTypeList) {
            _itemMember = [[SPMember alloc] initFromDictionary:dict[SPMemberDefinitionListMemberKey]];
            _inverseKeyName = [dict[SPMemberDefinitionInverseKeyNameKey] copy];
        }
    }
	
	return self;
}


- (NSString *)description {
	return [NSString stringWithFormat:@"%@ of type %@", self.keyName, _dictionaryForInitializer[SPMemberDefinitionTypeKey]];
}

- (id)JSONValueForMemberOnParentObject:(id)parentObject
{
    id value = [parentObject valueForKey:self.keyName];
    id JSONValue = [self JSONValueForMemberValue:value context:[parentObject managedObjectContext]];
    return JSONValue;
}

- (id)JSONValueForMemberValue:(id)value context:(NSManagedObjectContext *)context
{
    switch (self.type) {
        case SPMemberTypeText:
        case SPMemberTypeNumber:
        case SPMemberTypeBoolean:
            return value;
        case SPMemberTypeDate:
            if (!value) return nil;
            return @([(NSDate *)value timeIntervalSince1970]);
        case SPMemberTypeRelatedEntity:
            return [(SPManagedObject *)value simperiumKey];
        case SPMemberTypeEmbeddedRelatedEntity:
        {
            if (!value) return nil;
            NSMutableDictionary *JSONValue = [[NSMutableDictionary alloc] init];
            JSONValue[@"simperiumKey"] = [value valueForKey:@"simperiumKey"];
            for (SPMember *member in self.embeddedMembers) {
                id memberValue = [member JSONValueForMemberOnParentObject:value];
                if (memberValue) JSONValue[member.keyName] = memberValue;
            }
            return JSONValue;
        }
        case SPMemberTypeList:
        {
            NSMutableArray *items = [[NSMutableArray alloc] init];
            for (id item in value) {
                id JSONValue = [self.itemMember JSONValueForMemberValue:item context:context];
                if (JSONValue) [items addObject:JSONValue];
            }
            if (![value isKindOfClass:[NSOrderedSet class]] && ![value isKindOfClass:[NSArray class]]) {
                [items sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    return [[obj1 valueForKey:@"simperiumKey"] compare:[obj2 valueForKey:@"simperiumKey"]];
                }];
            }
            return (items.count ? items : nil);
        }
        case SPMemberTypeTransformable:
            if (self.JSONValueTransformer) return [self.JSONValueTransformer transformedValue:value];
            return value;
        case SPMemberTypeBinary:
        default:
            break;
    }
    [NSException raise:NSInternalInconsistencyException format:@"Simperium Error: Not a valid type for member %@",self];
    return nil;
    
}

- (void)setMemberValueFromJSONValue:(id)JSONValue onParentObject:(id)parentObject
{
    switch (_type) {
        case SPMemberTypeText:
        case SPMemberTypeNumber:
        case SPMemberTypeBoolean:
        case SPMemberTypeTransformable:
        case SPMemberTypeDate: {
            id memberValue = [self memberValueForJSONValue:JSONValue context:[parentObject managedObjectContext]];
            if (memberValue) {
                [parentObject setValue:memberValue forKey:self.keyName];
            } else {
                [parentObject setNilValueForKey:self.keyName];
            }
            break;
        }
        case SPMemberTypeRelatedEntity:
        {
            id memberValue = [self memberValueForJSONValue:JSONValue context:[parentObject managedObjectContext]];
            if (memberValue) {
                // Setup relationship as the object is already here :D
                [parentObject setValue:memberValue forKey:self.keyName];
            } else {
                [parentObject setNilValueForKey:self.keyName];
                
                if (![JSONValue isKindOfClass:[NSString class]] || [JSONValue length] == 0) return;
                // The relationship is missing so lets add it to the relationship resolver.
                NSString *fromKey = ((id<SPDiffable>)parentObject).simperiumKey;
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Let Simperium store the reference so it can be properly resolved when the object gets synced
                    SPBucket *bucket = ((id<SPDiffable>)parentObject).bucket;
                    [bucket.relationshipResolver addPendingRelationshipToKey:JSONValue fromKey:fromKey bucketName:bucket.name
                                                               attributeName:self.keyName storage:bucket.storage];
                });
            }
        }
            break;
        case SPMemberTypeEmbeddedRelatedEntity:
        {
            // lets delete any existing objects if no valid embedded object json is passed in
            SPEmbeddedManagedObject *existingObject = [parentObject valueForKey:self.keyName];
            
            NSString *simperiumKey = JSONValue[@"simperiumKey"];
            if (![JSONValue isKindOfClass:[NSDictionary class]] || ![simperiumKey isKindOfClass:[NSString class]] || [simperiumKey length] == 0 ) {
                if (existingObject) [self removeEmbeddedObject:existingObject withMembers:self.embeddedMembers];
                break;
            }
            
            // lets delete the existing object if it's not the same as the one we've got in the json
            if (existingObject && ![existingObject.simperiumKey isEqual:simperiumKey]) {
                [self removeEmbeddedObject:existingObject withMembers:self.embeddedMembers];
            }
            
            id memberValue = [self memberValueForJSONValue:JSONValue context:[parentObject managedObjectContext]];

            if (existingObject && memberValue && [memberValue isEqual:existingObject]) return;

            if (memberValue) {
                [parentObject setValue:memberValue forKey:self.keyName];
            } else {
                [parentObject setNilValueForKey:self.keyName];
            }
        }
            break;
        case SPMemberTypeList:
        {
            // TODO: implement for all list types
            if (self.itemMember.type != SPMemberTypeEmbeddedRelatedEntity) [NSException raise:NSInternalInconsistencyException format:@"Simperium Error: Unsupported list type"];
            
            // Delete all the existing embedded objects that don't have a simperkum key in the JSON value
            id<NSFastEnumeration>embeddedObjects = [parentObject valueForKey:self.keyName];
            NSSet *simperiumKeysInJSON =  [NSSet setWithArray:([JSONValue valueForKey:@"simperiumKey"] ?: @[])];
            
            for (SPEmbeddedManagedObject *embeddedObject in embeddedObjects) {
                if (![simperiumKeysInJSON containsObject:embeddedObject.simperiumKey]) {
                    [self removeEmbeddedObject:embeddedObject withMembers:self.itemMember.embeddedMembers];
                }
            }
            
            // create or update all the rest of them
            NSRelationshipDescription *relationshipDescription = ([[parentObject entity] relationshipsByName][self.keyName]);
            NSMutableSet *set = [[NSMutableSet alloc] init];
            NSMutableOrderedSet *orderedSet = [[NSMutableOrderedSet alloc] init];
            for (NSDictionary *embeddedObjectJSON in JSONValue) {
                if (![embeddedObjectJSON isKindOfClass:[NSDictionary class]]) continue;
                NSString *simperiumKey = embeddedObjectJSON[@"simperiumKey"];
                if (![simperiumKey isKindOfClass:[NSString class]] || [simperiumKey length] == 0) continue;
                SPEmbeddedManagedObject *object = [self.itemMember memberValueForJSONValue:embeddedObjectJSON context:[parentObject managedObjectContext]];
                if (relationshipDescription.isOrdered) {
                    [orderedSet addObject:object];
                } else {
                    [set addObject:object];
                }
            }

            if ([orderedSet isEqual:embeddedObjects]) return;

            // reset the relationship with all the new objects
            if (relationshipDescription.isOrdered) {
                [parentObject setValue:orderedSet forKey:self.keyName];
            } else {
                [parentObject setValue:set forKey:self.keyName];
            }
        }
        break;
        case SPMemberTypeBinary: // Not supported yet
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Simperium Error: Not a valid type for member %@",self];
            break;
    }

}

- (id)memberValueForJSONValue:(id)JSONValue context:(NSManagedObjectContext *)context
{
    switch (_type) {
        case SPMemberTypeText:
        case SPMemberTypeNumber:
        case SPMemberTypeBoolean:
            return JSONValue;
            
        case SPMemberTypeDate:
            if (!JSONValue || ![JSONValue isKindOfClass:[NSNumber class]]) return nil;
            return [NSDate dateWithTimeIntervalSince1970:[JSONValue doubleValue]];
            
        case SPMemberTypeRelatedEntity:
            if (![JSONValue isKindOfClass:[NSString class]] || [JSONValue length] == 0) return nil;
            return [SPManagedObject simperiumObjectWithEntityName:self.entityName simperiumKey:JSONValue managedObjectContext:context faults:NO];
            
        case SPMemberTypeEmbeddedRelatedEntity:
        {
            // Find an existing object if we can
            NSString *simperiumKey = JSONValue[@"simperiumKey"];
            SPEmbeddedManagedObject *existingObject = [SPEmbeddedManagedObject simperiumObjectWithEntityName:self.entityName simperiumKey:simperiumKey managedObjectContext:context faults:NO];
            
            // lets create an object if we didn't have a matching one and set it up on the relationship
            if (!existingObject) {
                existingObject = [self createEmbeddedObjectWithSimperiumKey:simperiumKey managedObjectContext:context];
            }
            // lets update all the values on the matching or newly created object
            for (SPMember *member in self.embeddedMembers) {
                [member setMemberValueFromJSONValue:JSONValue[member.keyName] onParentObject:existingObject];
            }
            return existingObject;
        }
        case SPMemberTypeTransformable:
        {
            id value = JSONValue;
            if (self.JSONValueTransformer) value = [self.JSONValueTransformer reverseTransformedValue:JSONValue];
            return value;
        }
            break;
        case SPMemberTypeBinary: // Not supported yet
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Simperium Error: Not a valid type for member %@",self];
            break;
    }
    
    return nil;
}

- (void)removeEmbeddedObject:(SPEmbeddedManagedObject *)existingObject withMembers:(NSArray *)members
{
    // We have to recursively remove any embedded entities before removing the existing object
    for (SPMember *member in members) {
        if (member.type == SPMemberTypeEmbeddedRelatedEntity || (member.type == SPMemberTypeList && member.itemMember.type == SPMemberTypeEmbeddedRelatedEntity)) {
            [member setMemberValueFromJSONValue:nil onParentObject:existingObject];
        }
    }
    [[existingObject managedObjectContext] deleteObject:existingObject];
}

- (SPEmbeddedManagedObject *)createEmbeddedObjectWithSimperiumKey:(NSString *)simperiumKey managedObjectContext:(NSManagedObjectContext *)context
{
    NSParameterAssert(simperiumKey.length > 0); NSParameterAssert(context);
    SPEmbeddedManagedObject *newObject = [NSEntityDescription insertNewObjectForEntityForName:self.entityName inManagedObjectContext:context];
    [newObject setValue:simperiumKey forKey:@"simperiumKey"];
    return newObject;
}



@end

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

@interface SPPNGImageToBase64Transformer : NSValueTransformer
@end
@implementation SPPNGImageToBase64Transformer
+ (BOOL)allowsReverseTransformation
{
    return YES;
}
+ (Class)transformedValueClass
{
   return [NSString class];
}
- (id)transformedValue:(id)value
{
    if (![value isKindOfClass:[UIImage class]]) return nil;
    NSData *data = UIImagePNGRepresentation(value);
    return [NSString sp_encodeBase64WithData:data];
}
- (id)reverseTransformedValue:(id)value
{
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSData *data = [NSData decodeBase64WithString:value];
    if (!data) return nil;
    return [[UIImage alloc] initWithData:data];
}
@end

#endif


