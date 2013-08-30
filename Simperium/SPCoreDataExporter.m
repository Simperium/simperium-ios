//
//  SPCoreDataExporter.m
//  Simperium
//
//  Created by Michael Johnston on 11-06-02.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SPCoreDataExporter.h"
#import "SPEmbeddedManagedObject.h"
#import "SPManagedObject.h"
#import "DDLog.h"

#import "SPSchema.h"
#import "SPMember.h"


static int ddLogLevel = LOG_LEVEL_INFO;

static NSString * const DisableSyncUserInfoKey = @"spDisableSync";
static NSString * const JSONTransformerNameUserInfoKey = @"spJSONTransformerName";
static NSString * const CustomOperationUserInfoKey = @"spOperationType";
static NSString * const EmbeddedRelationshipUserInfoKey = @"spEmbed";


@interface SPCoreDataExporter ()
{
	NSUInteger _exporterRecursiveCall;
}
@end

@implementation SPCoreDataExporter

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

-(id)init
{
    if ((self = [super init])) {
    }
    return self;
}

-(NSString *)simperiumTypeForAttribute:(NSAttributeDescription *)attribute
{
    // Check for overrides first
    NSString *override = [[attribute userInfo] objectForKey:@"spOverride"];
    if (override)
        return override;
    
    switch ([attribute attributeType]) {
        case NSStringAttributeType: return @"text";
        case NSInteger16AttributeType: return @"int";
        case NSInteger32AttributeType: return @"int";
        case NSInteger64AttributeType: return @"int";
        case NSDoubleAttributeType: return @"double";
        case NSFloatAttributeType: return @"double";
        case NSBooleanAttributeType: return @"boolean";
        case NSDateAttributeType: return @"date";
        case NSTransformableAttributeType: return @"transformable";
        case NSDecimalAttributeType: return @"double";
    }
    [NSException raise:NSInternalInconsistencyException format:@"Simperium couldn't load member %@ (unsupported type)", attribute.name];
	return nil;
}

-(BOOL)attributeAddedBySimperium:(NSAttributeDescription *) attr
{
	return ([@[ @"simperiumKey", @"ghostData" ] indexOfObject:attr.name] != NSNotFound);
}


-(NSDictionary *)exportModel:(NSManagedObjectModel *)model classMappings:(NSMutableDictionary *)classMappings
{
    
    // Construct a dictionary
    NSMutableDictionary *schemaDefinitionsByEntityName = [NSMutableDictionary dictionaryWithCapacity:[[model entities] count]];
    for (NSEntityDescription *entity in [model entities])
    {
		NSDictionary *schemaDefinition = [self exportSchemaDefinitionForBucketEntity:entity];
		if (!schemaDefinition) continue;
		
		classMappings[entity.name] = entity.managedObjectClassName;
		schemaDefinitionsByEntityName[entity.name] = schemaDefinition;
                
    }
    
    return schemaDefinitionsByEntityName;
    
    // For now, just print to log to make sure the export worked
    // Also freeze; copy/paste the log to a file, then comment out the export line so
    // this doesn't run again (hacky)
    DDLogVerbose(@"Simperium result of Core Data export: %@", schemaDefinitionsByEntityName);
    //NSAssert(0, @"Asserting to look at export log (hack)");
}

- (NSDictionary *)exportSchemaDefinitionForBucketEntity:(NSEntityDescription *)entity
{
	// Skip embeded entities as they'll get added through member definitions.
	if (entity.isAbstract || entity.userInfo[DisableSyncUserInfoKey] || [entity.name isEqualToString:NSStringFromClass(SPManagedObject.class)]) return nil;
	
	
	Class entityClass = NSClassFromString(entity.managedObjectClassName);
	if (![entityClass isSubclassOfClass:SPManagedObject.class]) return nil;
		
	return @{ SPSchemaDefinitionMembersKey: [self exportMemberDefinitionsFromEntity:entity skipRelationship:nil] };
}

-(NSArray *)exportMemberDefinitionsFromEntity:(NSEntityDescription *)entity skipRelationship:(NSRelationshipDescription *)skipRelationship
{
	_exporterRecursiveCall++;
	if (_exporterRecursiveCall > 500) [NSException raise:NSInternalInconsistencyException format:@"Simperium member definitions set up for more than 500 times, this is probably caused by a object recursive embedding structure with 3 or more objects (%s)",__PRETTY_FUNCTION__];
	
	NSMutableArray *members = [[NSMutableArray alloc] init];
    for (NSAttributeDescription *attribute in [entity.attributesByName allValues]) {
        NSDictionary *memberDefinition = [self exportMemberDefinitionForAttribute:attribute];
		if (!memberDefinition) continue;
		[members addObject:memberDefinition];
    }
    
    for (NSRelationshipDescription *relationship in [entity.relationshipsByName allValues]) {
		if (skipRelationship && [relationship isEqual:skipRelationship]) continue;
        // For the moment lets only allow entity members if the relationship is from a bucket object to bucket object not
        // from embedded object to bucket object. We have to change relationshipResolve to fix this.
        BOOL onlyEmbedded = [NSClassFromString(entity.managedObjectClassName) isSubclassOfClass:[SPEmbeddedManagedObject class]];
        NSDictionary *memberDefinition = [self exportMemberDefinitionForRelationship:relationship onlyEmbedded:onlyEmbedded];
        if (!memberDefinition) continue;
        [members addObject:memberDefinition];
    }
    
	return members;
}

- (NSDictionary *)exportMemberDefinitionForAttribute:(NSAttributeDescription *)attribute
{
	// Don't sync attributes used by simperium, transient attributes, or explicitly disabled attributes
	if ([self attributeAddedBySimperium:attribute] || attribute.isTransient || attribute.userInfo[DisableSyncUserInfoKey]) return nil;

	NSMutableDictionary *memberDefinition = [[NSMutableDictionary alloc] init];
	memberDefinition[SPMemberDefinitionKeyNameKey] = attribute.name;
	memberDefinition[SPMemberDefinitionTypeKey] = [self simperiumTypeForAttribute:attribute];
	
	
	if (attribute.userInfo[JSONTransformerNameUserInfoKey]) {
		memberDefinition[SPMemberDefinitionCustomJSONValueTransformerNameKey] = attribute.userInfo[JSONTransformerNameUserInfoKey];
	}
    
    if (attribute.userInfo[CustomOperationUserInfoKey]) {
        memberDefinition[SPMemberDefinitionCustomOperationKey] = attribute.userInfo[CustomOperationUserInfoKey];
    }
    
	return memberDefinition;
}


- (NSDictionary *)exportMemberDefinitionForRelationship:(NSRelationshipDescription *)relationship onlyEmbedded:(BOOL)onlyEmbedded
{
	// Don't sync relationships that are transient or explicitly disabled or that are to entities that don't sync.
	NSEntityDescription *destinationEntity = relationship.destinationEntity;
	if (relationship.isTransient || relationship.userInfo[DisableSyncUserInfoKey] || destinationEntity.userInfo[DisableSyncUserInfoKey]) return nil;
		
	Class destinationClass = NSClassFromString(relationship.destinationEntity.managedObjectClassName);

    BOOL isEmbeddedRelationship = (relationship.userInfo[EmbeddedRelationshipUserInfoKey] != nil);
	

	if (!isEmbeddedRelationship) {
		// Skip any relationships to non SPManagedObject entities
		if (![destinationClass isSubclassOfClass:[SPManagedObject class]] || onlyEmbedded) return nil;
		// TODO: Add support for the entity members on embedded objects

		// For now, we're only syncing relationships from many-to-one, not one-to-many, unless there's no inverse
		// (in which case the many-to-one won't exist)
		if ([relationship isToMany] && [relationship inverseRelationship]) return nil;
		
		return @{ SPMemberDefinitionKeyNameKey: relationship.name,
			SPMemberDefinitionTypeKey: @"entity",
			SPMemberDefinitionEntityNameKey: destinationEntity.name
			};
	} else {
        if (![destinationClass isSubclassOfClass:[SPEmbeddedManagedObject class]]) [NSException raise:NSInternalInconsistencyException format:@"Simperium Error: Cannot embed managed object entity with class (%@) that is not a subclass of %@", [destinationClass description],[SPEmbeddedManagedObject.class description]];
        NSRelationshipDescription *inverseRelationship = relationship.inverseRelationship;
        if (!inverseRelationship) [NSException raise:NSInternalInconsistencyException format:@"Simperium Error: Embedded object relationship must have inverse relationship.\n%@",relationship];
		NSDictionary *memberObjectDefinition = @{ SPMemberDefinitionKeyNameKey: relationship.name,
											SPMemberDefinitionTypeKey: @"object",
											SPMemberDefinitionEntityNameKey: destinationEntity.name,
											SPMemberDefinitionMembersKey: [self exportMemberDefinitionsFromEntity:destinationEntity skipRelationship:inverseRelationship],
                                            SPMemberDefinitionInverseKeyNameKey: inverseRelationship.name
											};
											
		if (![relationship isToMany]) return memberObjectDefinition;
		
		return @{ SPMemberDefinitionKeyNameKey: relationship.name,
		 SPMemberDefinitionTypeKey: @"list",
		 SPMemberDefinitionListMemberKey: memberObjectDefinition,
            SPMemberDefinitionInverseKeyNameKey: inverseRelationship.name
		 };
	}
}





@end
