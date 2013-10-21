//
//  SPCoreDataExporter.m
//  Simperium
//
//  Created by Michael Johnston on 11-06-02.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SPCoreDataExporter.h"
#import "SPManagedObject.h"
#import "DDLog.h"
#import "SPMemberBinaryInfo.h"



static int ddLogLevel = LOG_LEVEL_INFO;

@implementation SPCoreDataExporter

+(int)ddLogLevel
{
    return ddLogLevel;
}

+(void)ddSetLogLevel:(int)logLevel
{
    ddLogLevel = logLevel;
}

-(NSString *)simperiumTypeForAttribute:(NSAttributeDescription *)attribute
{
    // Check for overrides first
    NSString *override = [[attribute userInfo] objectForKey:@"spOverride"];
    if (override) {
        return override;
	}
    
    switch ([attribute attributeType]) {
        case NSStringAttributeType: return @"text";
        case NSInteger16AttributeType: return @"int";
        case NSInteger32AttributeType: return @"int";
        case NSInteger64AttributeType: return @"int";
        case NSDoubleAttributeType: return @"double";
        case NSFloatAttributeType: return @"double";
        case NSBooleanAttributeType: return @"int";
        case NSDateAttributeType: return @"date";
        case NSTransformableAttributeType: return @"base64";
        case NSDecimalAttributeType: return @"double";
    }
    return nil;
}

-(BOOL)attributeAddedBySimperium:(NSAttributeDescription *) attr
{
    return [[attr name] compare:@"simperiumKey"] == NSOrderedSame ||
        [[attr name] compare:@"ghostData"] == NSOrderedSame;
}

-(void)prepareBinaryAttributesFrom:(NSEntityDescription *)entityDesc
{
	/**		
		Notes:
		======
		Binary Sync needs two attributes:
			- [name]	 :: NSBinaryDataAttributeType
			- [name]Info :: NSStringAttributeType
	
		The Info attribute needs an 'spOverride' with 'binaryInfo' in it.
		In this method we'll enforce that if the 'Data' attribute is present, an 'Info' counterpart should be present as well.
		Plus, we'll inject the binaryInfo override, so the metadata can be handled by SPMemberBinaryInfo
	 */
	
    for (NSAttributeDescription *attr in [entityDesc.attributesByName allValues]) {
		if(attr.attributeType != NSBinaryDataAttributeType) {
			continue;
		}
		
		NSString *infoKey = [attr.name stringByAppendingString:SPMemberBinaryInfoSuffix];
		NSAttributeDescription *infoAttr = [[entityDesc attributesByName] objectForKey:infoKey];
		NSAssert(infoAttr, @"Simperium: Missing metadata attribute [%@] for Binary Member [%@]", infoKey, attr.name);
		
		// Inject the binaryInfo override: The Binary Metadata attribute needs to be handled by SPMemberBinaryInfo
		NSMutableDictionary *userInfo = [infoAttr.userInfo mutableCopy];
		userInfo[@"spOverride"] = @"binaryInfo";
		infoAttr.userInfo = userInfo;
	}
}

-(void)addMembersFrom:(NSEntityDescription *)entityDesc to:(NSMutableArray *)members
{
    // Don't add members from SPManagedObject
    if ([[entityDesc name] compare:NSStringFromClass([SPManagedObject class])] == NSOrderedSame) {
        return;
	}
    
    for (NSAttributeDescription *attr in [[entityDesc attributesByName] allValues]) {
        // Don't sync certain attributes
        if ([self attributeAddedBySimperium:attr]) {
            continue;
		}
        
        if ([attr isTransient]) {
            continue;
		}
		
		// Don't export binaryData attributes. Those fields will be handled by SPBinaryManager
		if (attr.attributeType == NSBinaryDataAttributeType) {
			continue;
		}
        
        // Attributes can be manually excluded from syncing
        if ([[attr userInfo] objectForKey:@"spDisableSync"]) {
            continue;
		}
        
        NSMutableDictionary *member = [NSMutableDictionary dictionaryWithCapacity:4];

        id defaultValue = [attr defaultValue];
        if (defaultValue) {
            [member setObject:defaultValue forKey:@"defaultValue"];
		}
		
        NSString *type = [self simperiumTypeForAttribute: attr];
        NSAssert1(type != nil, @"Simperium couldn't load member %@ (unsupported type)", [attr name]);
		
        [member setObject:type forKey:@"type"];
        [member setObject:attr.name forKey:@"name"];
        [member setObject:@"default" forKey:@"resolutionPolicy"];
		
        if (attr.attributeType == NSTransformableAttributeType && attr.valueTransformerName != nil) {
            [member setObject:attr.valueTransformerName forKey:@"valueTransformerName"];
        }
		
        [members addObject: member];
    }
    
    for (NSString *relationshipName in [[entityDesc relationshipsByName] allKeys]) {
        NSRelationshipDescription *rel = [[entityDesc relationshipsByName] objectForKey:relationshipName];
        
        // Relationships can be manually excluded from syncing
        if ([[rel userInfo] objectForKey:@"spDisableSync"]) {
            continue;
		}
        
        // For now, we're only syncing relationships from many-to-one, not one-to-many, unless there's no inverse
        // (in which case the many-to-one won't exist)
        if ([rel isToMany] && [rel inverseRelationship] != nil) {
            continue;
		}
        
        NSMutableDictionary *member = [NSMutableDictionary dictionaryWithCapacity:4];
        [member setObject:[rel name] forKey:@"name"];
        [member setObject:@"default" forKey:@"resolutionPolicy"];
        [member setObject:@"entity" forKey:@"type"];
        [member setObject:[rel destinationEntity].name forKey:@"entityName"];
        [members addObject: member];
    }
    
    // Now recursively add all parent entity members and relationships
    // (not needed, looks like they're already included in attributesByName
//    if ([entityDesc superentity])
//        [self addMembersFrom:[entityDesc superentity] to:members];
}

-(NSDictionary *)exportModel:(NSManagedObjectModel *)model classMappings:(NSMutableDictionary *)classMappings
{
    // Construct a dictionary
    NSMutableDictionary *definitions = [NSMutableDictionary dictionaryWithCapacity:[[model entities] count]];
    for (NSEntityDescription *entityDesc in model.entities) {
        // Certain entities don't need to be synced
        if ([entityDesc isAbstract]) {
            continue;
		}
        
        if ([[entityDesc userInfo] objectForKey:@"spDisableSync"]) {
            continue;
		}
        
        if ([[entityDesc name] compare:NSStringFromClass([SPManagedObject class])] == NSOrderedSame) {
            continue;
		}
        
        NSString *className = [entityDesc managedObjectClassName];
        Class cls = NSClassFromString(className);
        if (![cls isSubclassOfClass:[SPManagedObject class]]) {
            continue;
		}
        
        // Load the entity data
        NSMutableDictionary *data = [NSMutableDictionary dictionaryWithCapacity: 3];
        [data setObject:className forKey:@"class"];
        [definitions setObject:data forKey:[entityDesc name]];
        
        // List? (just false for now...edit manually later if needed
        [data setObject:[NSNumber numberWithBool:NO] forKey:@"list"];
        
        // Members
        NSMutableArray *members = [NSMutableArray arrayWithCapacity:[[entityDesc properties] count]];
        [data setObject: members forKey:@"members"];
        
		// Validate & Wire Binary Attributes!
		[self prepareBinaryAttributesFrom:entityDesc];
		
        // Add all this entity's attributes and relationships
        [self addMembersFrom:entityDesc to:members];
        
        [classMappings setObject:className forKey: [entityDesc name]];
    }
    
#ifdef DEBUG_EXPORT_OUTPUT
    // For now, just print to log to make sure the export worked
    // Also freeze; copy/paste the log to a file, then comment out the export line so
    // this doesn't run again (hacky)
    DDLogVerbose(@"Simperium result of Core Data export: %@", definitions);
    NSAssert(0, @"Asserting to look at export log (hack)");
#endif
	
    return definitions;
}

@end
