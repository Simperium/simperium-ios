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
#import "JSONKit+Simperium.h"
#import "SPLogger.h"
#import "SPDiffable.h"
#import "SPSchema.h"
#import "SPJSONDiff.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static SPLogLevels logLevel = SPLogLevelsInfo;


#pragma mark ====================================================================================
#pragma mark SPDiffer
#pragma mark ====================================================================================

@implementation SPDiffer

- (instancetype)initWithSchema:(SPSchema *)aSchema {
    self = [super init];
    if (self) {
        self.schema = aSchema;
    }
    
    return self;
}


// Construct a diff for newly added entities
- (NSMutableDictionary *)diffForAddition:(id<SPDiffable>)object {
    NSMutableDictionary *diff = [NSMutableDictionary dictionaryWithCapacity: [self.schema.members count]];

    for (SPMember *member in [self.schema.members allValues]) {
        id JSONValue = [member JSONValueForMemberOnParentObject:object];
        NSDictionary *memberDiff = SPDiffObjects(nil, JSONValue, member.policy);
        if (memberDiff) {
            [diff setObject:memberDiff forKey:member.keyName];
        }
    }
    return diff;
}

//  Calculates the diff required to go from Dictionary-state into Object-state
- (NSDictionary *)diffFromDictionary:(NSDictionary *)dict toObject:(id<SPDiffable>)object {
    // changes contains the operations for every key that is different
    NSMutableDictionary *changes = [NSMutableDictionary dictionaryWithCapacity:3];

    // We cycle through all members of the ghost and check their values against the entity
    // In the JS version, members can be added/removed this way too if a member is present in one entity
    // but not the other; ignore this functionality for now

    NSDictionary *currentDiff = nil;
    for (SPMember *member in [self.schema.members allValues])
    {
        NSString *key = [member keyName];
        // Make sure the member exists and is tracked by Simperium
        SPMember *thisMember = [self.schema memberForKey:key];
        if (!thisMember) {
            SPLogWarn(@"Simperium warning: trying to diff a member that doesn't exist (%@) from ghost: %@", key, [dict description]);
            continue;
        }

		id currentValueJSON = [thisMember JSONValueForMemberOnParentObject:object];
		id dictValueJSON    = dict[key];

		// Perform the actual diff; the mechanics of the diff will depend on the member policy
        currentDiff = SPDiffObjects(dictValueJSON, currentValueJSON, member.policy);

        // If there was no difference, then don't add any changes for this member
        if (currentDiff == nil || [currentDiff count] == 0) {
            continue;
        }
        
        // Otherwise, add this as a change
        [changes setObject:currentDiff forKey:[thisMember keyName]];
    }

    return changes;
}

// Apply an incoming diff to this entity instance
- (BOOL)applyDiffFromDictionary:(NSDictionary *)diff toObject:(id<SPDiffable>)object error:(NSError **)error {
    // Process each change in the diff
    for (NSString *key in diff.allKeys) {
        NSDictionary *change    = diff[key];

        // Failsafe: This should never happen
        if (change == nil) {
            continue;
        }
        
        // Make sure the member exists and is tracked by Simperium
        SPMember *member = [self.schema memberForKey:key];
        if (!member) {
            SPLogWarn(@"Simperium warning: applyDiff for a member that doesn't exist (%@): %@", key, [change description]);
            continue;
        }
        id currentValue = [member JSONValueForMemberOnParentObject:object];

        NSError *theError   = nil;
        id newValue         = SPApplyDiff(currentValue, change, &theError);

        // On error: halt and relay the error to the caller
        if (theError) {
            if (error) {
                *error = theError;
            }
            return NO;
        }

        [member setMemberValueFromJSONValue:newValue onParentObject:object];
    }

    return YES;
}

// Same strategy as applyDiff, but do it to the ghost's memberData
// Note that no conversions are necessary here since all data is in JSON-compatible format already
- (BOOL)applyGhostDiffFromDictionary:(NSDictionary *)diff toObject:(id<SPDiffable>)object error:(NSError **)error {
    // Create a copy of the ghost's data and update any members that have changed
    NSMutableDictionary *ghostMemberData = object.ghost.memberData;
    NSMutableDictionary *newMemberData = ghostMemberData ? [ghostMemberData mutableCopy] : [NSMutableDictionary dictionaryWithCapacity:diff.count];
    for (NSString *key in diff.allKeys) {
        NSDictionary *change    = diff[key];
        
        // Failsafe: This should never happen
        if (change == nil) {
            continue;
        }

        // Make sure the member exists and is tracked by Simperium
        SPMember *member = [self.schema memberForKey:key];
        if (!member) {
            SPLogWarn(@"Simperium warning: applyGhostDiff for a member that doesn't exist (%@): %@", key, [change description]);
            continue;
        }

        id currentGhostValue = newMemberData[key];

        NSError *theError   = nil;
        id newValue         = SPApplyDiff(currentGhostValue, change, &theError);

        // On error: halt and relay the error to the caller
        if (theError) {
            if (error) {
                *error = theError;
            }
            return NO;
        }

        if (newValue) {
            newMemberData[key] = newValue;
        } else {
            [newMemberData removeObjectForKey:key];
        }
    }

    object.ghost.memberData = newMemberData;
    
    return YES;
}

- (NSDictionary *)transform:(id<SPDiffable>)object diff:(NSDictionary *)diff oldDiff:(NSDictionary *)oldDiff oldGhost:(SPGhost *)oldGhost error:(NSError **)error {
    NSMutableDictionary *newDiff = [NSMutableDictionary dictionary];
    // Transform diff first, and then apply it
    for (NSString *key in diff.allKeys) {
        NSDictionary *change    = diff[key];
        NSDictionary *oldChange = oldDiff[key];

        // Make sure the member exists and is tracked by Simperium
        SPMember *member = [self.schema memberForKey:key];
        id ghostValue = oldGhost.memberData[key];
		if (!member) {
			SPLogError(@"Simperium error: transform diff for a member that doesn't exist (%@): %@", key, [change description]);
			continue;
		}
        if (!ghostValue) {

            // Happy Inspector: If the ghost value is nil, but both diffs are an add operation,
            //                  transform the new diff into a replace operation
            if ([change[OP_OP] isEqualToString:OP_OBJECT_ADD] && [oldChange[OP_OP] isEqualToString:OP_OBJECT_ADD]) {
                newDiff[key] = @{OP_OP : OP_REPLACE, OP_VALUE : change[OP_VALUE]};
                continue;
            }

			SPLogError(@"Simperium error: transform diff for a ghost member (ghost %@, memberData %@) that doesn't exist (%@): %@", oldGhost, oldGhost.memberData, key, [change description]);
            continue;
        }
        
        if (!oldChange) {
            newDiff[key] = [change copy];
            continue;
        }
		
		NSError *theError       = nil;
        NSDictionary *newChange = SPTransformDiff(ghostValue, change, oldChange, member.policy, &theError);

        // On error: halt and relay the error to the caller
        if (theError) {
            if (error) {
                *error = theError;
            }
            return nil;
        }

        if (newChange) {
            [newDiff setObject:newChange forKey:key];
        } else {
            // If there was no transformation required, just use the original change
            NSDictionary *changeCopy = [change copy];
            [newDiff setObject:changeCopy forKey:key];
        }
    }
    
    return newDiff;
}

@end
