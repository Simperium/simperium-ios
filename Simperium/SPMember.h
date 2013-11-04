//
//  SPMember.h
//  Simperium
//
//  Created by Michael Johnston on 11-02-12.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPDiffable.h"

@class SPManagedObject;

extern NSString * const OP_OP;
extern NSString * const OP_VALUE;
extern NSString * const OP_REPLACE;
extern NSString * const OP_LIST_INSERT;
extern NSString * const OP_LIST_DELETE;
extern NSString * const OP_OBJECT_ADD;
extern NSString * const OP_OBJECT_REMOVE;
extern NSString * const OP_INTEGER;
extern NSString * const OP_LIST;
extern NSString * const OP_LIST_DMP;
extern NSString * const OP_OBJECT;
extern NSString * const OP_STRING;

extern NSString * const SPMemberDefinitionKeyNameKey;
extern NSString * const SPMemberDefinitionTypeKey;
extern NSString * const SPMemberDefinitionCustomOperationKey; // returns a string to the custom otype. This gets put in member policy
extern NSString * const SPMemberDefinitionCustomJSONValueTransformerNameKey; // returns the name for a custom JSONValueTransformer
extern NSString * const SPMemberDefinitionMembersKey; // The key to an array of SPMemeberDefinitionDictionaries (only required for SPMemberObject definitions)
extern NSString * const SPMemberDefinitionEntityNameKey; // The key to an entity name string (only required for SPMemberEntity and SPMemberObject defintions).
extern NSString * const SPMemberDefinitionListMemberKey; // The key to a member definition for objects in a list (only required for SPMemberList definitions).
extern NSString * const SPMemberDefinitionInverseKeyNameKey; // The a string for the key path of the inverse relationship for embedded objects


typedef NS_ENUM(NSInteger, SPMemberType)
{
    SPMemberTypeText,
    SPMemberTypeDate,
    SPMemberTypeNumber,
    SPMemberTypeBoolean,
    SPMemberTypeList,
    SPMemberTypeTransformable,
    SPMemberTypeBinary,
    SPMemberTypeRelatedEntity,
    SPMemberTypeEmbeddedRelatedEntity,
};



@interface SPMember : NSObject {
}

@property (nonatomic, readonly, strong) NSString *keyName;

-(SPMember *)initFromDictionary:(NSDictionary *)dict;


// TODO: Implement
- (void)applyBucketPolicy:(NSDictionary *)bucketPolicy;
// Returns a generated policy from the members
@property (nonatomic, readonly, strong) NSDictionary *policy;


@property (nonatomic, assign, readonly) SPMemberType type;
@property (nonatomic, strong, readonly) SPMember *itemMember; // Used only for SPMemberTypeEmbeddedList
@property (nonatomic, strong, readonly) NSArray *embeddedMembers; // Used only for SPMemberTypeEmbeddedRelatedEntity 
@property (nonatomic, copy, readonly) NSString *entityName; // Used only for SPMemberTypeEmbeddedRelatedEntity, SPMemberTypeRelatedEntity
@property (nonatomic, readonly) NSString *inverseKeyName; // Used only for SPMemberTypeEmbeddedRelatedEntity & SPMemberTypeEmbeddedList with SPMemberTypeEmbeddedRelatedEntity item member.


- (id)JSONValueForMemberOnParentObject:(id)parentObject;
- (void)setMemberValueFromJSONValue:(id)JSONValue onParentObject:(id)parentObject;

@end
