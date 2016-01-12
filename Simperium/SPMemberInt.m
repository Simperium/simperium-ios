//
//  SPMemberInt.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPMemberInt.h"
#import "SPLogger.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static SPLogLevels logLevel = SPLogLevelsInfo;


#pragma mark ====================================================================================
#pragma mark SPMemberInt
#pragma mark ====================================================================================

@implementation SPMemberInt

- (id)defaultValue {
    return @(0);
}

- (NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue {
    
    // Failsafe: In Release Builds, let's return an empty diff if the input is invalid
    NSString *mismatchMessage = @"Simperium error: couldn't diff ints because their classes weren't NSNumber";
    NSAssert([thisValue isKindOfClass:[NSNumber class]] && [otherValue isKindOfClass:[NSNumber class]], mismatchMessage);
    
    if (![thisValue isKindOfClass:[NSNumber class]] || ![otherValue isKindOfClass:[NSNumber class]]) {
        SPLogError(mismatchMessage);
        return @{ };
    }
    
    if ([thisValue isEqualToNumber:otherValue]) {
        return @{ };
    }
    
    // Construct the diff in the expected format
    return @{
        OP_OP : OP_REPLACE,
        OP_VALUE : otherValue
    };
}

- (id)getValueFromDictionary:(NSDictionary *)dict key:(NSString *)key object:(id<SPDiffable>)object {
    id value = [super getValueFromDictionary:dict key:key object:object];
    
    // Failsafe: Attempt to parse the int value
    if ([value isKindOfClass:[NSString class]]) {
        value = @([((NSString *)value) integerValue]);
    }
    
    return value;
}

- (id)applyDiff:(id)thisValue otherValue:(id)otherValue error:(NSError **)error {
    NSAssert(thisValue == nil || [thisValue isKindOfClass:[NSNumber class]], @"Simperium error: couldn't apply diff to double because its class wasn't NSNumber");
    NSAssert(otherValue == nil || [otherValue isKindOfClass:[NSNumber class]], @"Simperium error: couldn't apply diff to double because its class wasn't NSNumber");
    
    // Integer changes just replace the previous value by default
    // TODO: Not sure if this should be a copy or not...
    return otherValue;
}

- (NSDictionary *)transform:(id)thisValue otherValue:(id)otherValue oldValue:(id)oldValue error:(NSError **)error {
    // By default, don't transform anything, and take the local pending value
    return [NSDictionary dictionaryWithObjectsAndKeys:OP_REPLACE, OP_OP, thisValue, OP_VALUE, nil];
}

@end
