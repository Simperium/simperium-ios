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
@synthesize bucket;
@dynamic simperiumKey;
@dynamic ghostData;

- (void)simperiumSetValue:(id)value forKey:(NSString *)key {
    [self safeSetValue:value forKey:key];
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
    
    bucket = bucketList[self.entity.name];
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
        ghostData = [[[ghost dictionary] sp_JSONString] copy];
        ghost.needsSave = NO;
    }
}

- (void)setGhostData:(NSString *)aString {
    // Core Data compliant way to update members
    [self willChangeValueForKey:@"ghostData"];
    // NSString implements NSCopying, so copy the attribute value
    NSString *newStr = [aString copy];
    [self setPrimitiveValue:newStr forKey:@"ghostData"]; // setPrimitiveContent will make it nil if the string is empty
    [self didChangeValueForKey:@"ghostData"];
}


- (void)setSimperiumKey:(NSString *)aString {
    // Core Data compliant way to update members
    [self willChangeValueForKey:@"simperiumKey"];
    // NSString implements NSCopying, so copy the attribute value
    NSString *newStr = [aString copy];
    [self setPrimitiveValue:newStr forKey:@"simperiumKey"]; // setPrimitiveContent will make it nil if the string is empty
    [self didChangeValueForKey:@"simperiumKey"];
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
        SPMember *member = [bucket.differ.schema memberForKey:memberKey];
        if (member) {
            id data = [member getValueFromDictionary:memberData key:memberKey object:self];
            
            // This sets the actual instance data
            [self safeSetValue:data forKey:[member keyName]];
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
    
    for (SPMember *member in [bucket.differ.schema.members allValues]) {
        id data = [self valueForKey:[member keyName]];
        
        // The setValue:forKey:inDictionary: method can perform conversions to JSON-compatible formats
        [member setValue:data forKey:[member keyName] inDictionary:dict];
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

- (void)safeSetValue:(id)value forKey:(NSString*)key {
    // first we get the objc_property_t that corresponds to the key
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList([self class], &propertyCount);
    objc_property_t property;
    for (int i=0; i<propertyCount; i++) {
        objc_property_t propertyi = properties[i];
        const char *propertyName = property_getName(propertyi);
        NSString *keyName = [NSString stringWithUTF8String:propertyName];
        if([keyName isEqualToString:key]) {
            property = propertyi;
        }
    }
    free(properties);
    
    if (!property) {
        // property doesn't exist, we can't set it
        return;
    }
    
    if (value) {
        char *typeEncoding = NULL;
        typeEncoding = property_copyAttributeValue(property, "T");
        switch (typeEncoding[0]) {
            case '@': {
                // We get the class of the property
                Class class = nil;
                if (strlen(typeEncoding) >= 3) {
                    char *className = strndup(typeEncoding+2, strlen(typeEncoding)-3);
                    class = NSClassFromString([NSString stringWithUTF8String:className]);
                }
                
                //We check for type mismatch
                if ([value isKindOfClass:class]) {
                    [self setValue:value forKey:key];
                }
                else {
                    NSLog(@"Simperium error: type mismatch");
                    // TODO: handle exception
                }
            }
                
            default: {
                break;
            }
        }
        free(typeEncoding);
    }
    else {
        [self setValue:value forKey:key];
    }

}


@end
