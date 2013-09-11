//
//  SPSchema.m
//  Simperium
//
//  Created by Michael Johnston on 11-05-16.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "Simperium.h"
#import "SPSchema.h"
#import "SPMember.h"
#import "SPMemberBinary.h"


NSString * const SPSchemaDefinitionMembersKey = @"members";

@implementation SPSchema
@synthesize bucketName;
@synthesize members;
@synthesize binaryMembers;
@synthesize dynamic;


// Loads an entity's definition (name, members, their types, etc.) from a plist dictionary
-(id)initWithBucketName:(NSString *)name data:(NSDictionary *)definition
{
    if (self = [super init]) {
        bucketName = [name copy];
        NSArray *memberList = [definition valueForKey:SPSchemaDefinitionMembersKey];
        members = [NSMutableDictionary dictionaryWithCapacity:3];
        binaryMembers = [NSMutableArray arrayWithCapacity:3];
        for (NSDictionary *memberDict in memberList) {

			SPMember *member = [[SPMember alloc] initFromDictionary:memberDict];
            [members setObject:member forKey:member.keyName];

            if ([member isKindOfClass:[SPMemberBinary class]])
                [binaryMembers addObject: member];
        }        
    }
    
    return self;
}


-(NSString *)bucketName {
	return bucketName;
}

-(void)addMemberForObject:(id)object key:(NSString *)key {
    if (!dynamic)
        return;
    
    if ([self memberForKey:key])
        return;
    
    NSString *type = @"unsupported";
    if ([object isKindOfClass:[NSString class]])
        type = @"text";
    else if ([object isKindOfClass:[NSNumber class]])
        type = @"double";
    
    NSDictionary *memberDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                type, @"type",
                                key, @"name", nil];

    SPMember *member = [[SPMember alloc] initFromDictionary:memberDict];
    [members setObject:member forKey:member.keyName];
    
}

-(SPMember *)memberForKey:(NSString *)memberName {
    return [members objectForKey:memberName];
}


@end
