//
//  SPDiffer.m
//
//  Created by Michael Johnston on 11-02-11.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SPDiffer.h"
#import "SPMember.h"
#import "Simperium.h"
#import "SPGhost.h"
#import "JSONKit.h"
#import "DDLog.h"
#import "SPDiffable.h"
#import "SPSchema.h"
#import "SPJSONDiff.h"

@interface SPDiffer(Private)
@end

@implementation SPDiffer
@synthesize schema;

static int ddLogLevel = LOG_LEVEL_INFO;

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}


- (id)initWithSchema:(SPSchema *)aSchema {
    if ((self = [super init])) {
        self.schema = aSchema;
    }
    
    return self;
}


// Construct a diff for newly added entities
- (NSMutableDictionary *)diffForAddition:(id<SPDiffable>)object {
    NSMutableDictionary *diff = [NSMutableDictionary dictionaryWithCapacity: [schema.members count]];
    
    for (SPMember *member in [schema.members allValues]) {
        id JSONValue = [member JSONValueForMemberOnParentObject:object];
        NSDictionary *memberDiff = SPDiffObjects(nil, JSONValue, member.policy);
        if (memberDiff) {
            [diff setObject:memberDiff forKey:member.keyName];
        }
	}
    return diff;
}

// Construct a diff against a particular dictionary of data, such as a ghost dictionary
- (NSDictionary *)diff:(id<SPDiffable>)object withDictionary:(NSDictionary *)dict {
	// changes contains the operations for every key that is different
	NSMutableDictionary *changes = [NSMutableDictionary dictionaryWithCapacity:3];
	
	// We cycle through all members of the ghost and check their values against the entity
	// In the JS version, members can be added/removed this way too if a member is present in one entity
	// but not the other; ignore this functionality for now
	
	for (SPMember *member in [schema.members allValues])
    {
        id dictionaryJSONValue = dict[member.keyName];
        id objectJSONValue = [member JSONValueForMemberOnParentObject:object];
        
        SPDiff *diff = SPDiffObjects(dictionaryJSONValue, objectJSONValue, member.policy);

		if (diff == nil || [diff count] == 0)
			continue;
		
		// Otherwise, add this as a change
		[changes setObject:diff forKey:member.keyName];
	}

	return changes;	
}

// Apply an incoming diff to this entity instance
- (void)applyDiff:(NSDictionary *)diff to:(id<SPDiffable>)object {
	// Process each change in the diff
	for (NSString *memberKey in [diff allKeys]) {
		// Make sure the member exists and is tracked by Simperium
		SPMember *member = [schema memberForKey: memberKey];
        NSDictionary *memberDiff = diff[memberKey];
		if (!member) {
			DDLogWarn(@"Simperium warning: applyDiff for a member that doesn't exist (%@): %@", memberKey, [memberDiff description]);
			continue;
		}
        id currentValue = [member JSONValueForMemberOnParentObject:object];
        id newValue = SPApplyDiff(currentValue, memberDiff);
        [member setMemberValueFromJSONValue:newValue onParentObject:object];
		        
    }
}

// Same strategy as applyDiff, but do it to the ghost's memberData
// Note that no conversions are necessary here since all data is in JSON-compatible format already
- (void)applyGhostDiff:(NSDictionary *)diff to:(id<SPDiffable>)object {
	// Create a copy of the ghost's data and update any members that have changed
	NSMutableDictionary *ghostMemberData = [[object ghost] memberData];
	NSMutableDictionary *newMemberData = ghostMemberData ? [ghostMemberData mutableCopy] : [NSMutableDictionary dictionaryWithCapacity: [diff count]];
	for (NSString *key in [diff allKeys]) {
        
		NSDictionary *memberDiff = [diff objectForKey:key];
        // This should never happen, but it can if a change somehow slips in from a PUT request
        if (memberDiff == nil)
            continue;
        
        SPMember *member = [schema memberForKey: key];
        // Make sure the member exists and is tracked by Simperium
        if (!member) {
            DDLogWarn(@"Simperium warning: applyGhostDiff for a member that doesn't exist (%@): %@", key, [memberDiff description]);
            continue;
        }
		
        id currentGhostValue = newMemberData[key];
        id newGhostValue = SPApplyDiff(currentGhostValue, memberDiff);
        if (newGhostValue) {
            newMemberData[key] = newGhostValue;
        } else {
            [newMemberData removeObjectForKey:key];
        }
	}
	[object ghost].memberData = newMemberData;
}

- (NSDictionary *)transform:(id<SPDiffable>)object diff:(NSDictionary *)diff oldDiff:(NSDictionary *)oldDiff oldGhost:(SPGhost *)oldGhost {
    
	NSMutableDictionary *newDiff = [NSMutableDictionary dictionary];
	// Transform diff first, and then apply it
    NSMutableDictionary *oldGhostMemberData = oldGhost.memberData;
	for (NSString *key in [diff allKeys]) {
		NSDictionary *memberDiff = [diff objectForKey:key];
		NSDictionary *oldMemberDiff = [oldDiff objectForKey:key];
		
		// Make sure the member exists and is tracked by Simperium
		SPMember *member = [schema memberForKey: key];
		if (!member) {
			DDLogError(@"Simperium error: transform diff for a member that doesn't exist (%@): %@", key, [memberDiff description]);
			continue;
		}
        id ghostValue = oldGhostMemberData[key];
        if (!ghostValue) {
			DDLogError(@"Simperium error: transform diff for a ghost member (ghost %@, memberData %@) that doesn't exist (%@): %@", oldGhost, oldGhost.memberData, key, [memberDiff description]);
            continue;
        }


        SPDiff *transformedMemberDiff = SPTransformDiff(ghostValue, memberDiff, oldMemberDiff, member.policy);
		if (transformedMemberDiff)
			[newDiff setObject:transformedMemberDiff forKey:key];
		else {
			// If there was no transformation required, just use the original change
			[newDiff setObject:[memberDiff copy] forKey:key];
        }
	}
	
	return newDiff;
}

@end
