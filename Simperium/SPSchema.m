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


NSString * const SPSchemaDefinitionMembersKey = @"members";

@interface SPSchema ()
@property (nonatomic, strong) NSDictionary *memberMap;
@end


@implementation SPSchema

// Loads an entity's definition (name, members, their types, etc.) from a plist dictionary
- (id)initWithBucketName:(NSString *)name data:(NSDictionary *)definition {
    if (self = [super init]) {
        _bucketName = [name copy];
        NSArray *memberList = [definition valueForKey:SPSchemaDefinitionMembersKey];
        _members = [NSMutableDictionary dictionaryWithCapacity:3];
        _binaryMembers = [NSMutableArray arrayWithCapacity:3];
        for (NSDictionary *memberDict in memberList) {
			SPMember *member = [[SPMember alloc] initFromDictionary:memberDict];
            [_members setObject:member forKey:member.keyName];
        }        
    }
    
    return self;
}

- (void)addMemberForObject:(id)object key:(NSString *)key {
    if (!_dynamic) {
        return;
	}
    
    if ([self memberForKey:key]) {
        return;
	}
    
    NSString *type = @"unsupported";
    if ([object isKindOfClass:[NSString class]]) {
        type = @"text";
	} else if ([object isKindOfClass:[NSNumber class]]) {
        type = @"double";
	}

    NSDictionary *memberDict = @{ @"type" : type,
								  @"name" : key };
    SPMember *member = [[SPMember alloc] initFromDictionary:memberDict];
    [self.members setObject:member forKey:member.keyName];
}

- (SPMember *)memberForKey:(NSString *)memberName {
    return _members[memberName];
}

@end
