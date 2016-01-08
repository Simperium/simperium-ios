//
//  SPMemberDouble.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPMemberDouble.h"
#import "SPLogger.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static SPLogLevels logLevel = SPLogLevelsInfo;


#pragma mark ====================================================================================
#pragma mark SPMemberDouble
#pragma mark ====================================================================================

@implementation SPMemberDouble

- (id)defaultValue {
    return [NSNumber numberWithDouble:0];
}

- (NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue {
    
    // Failsafe: In Release Builds, let's return an empty diff if the input is invalid
    NSString *mismatchMessage = @"Simperium error: couldn't diff doubles because their classes weren't NSNumber";
    NSAssert([thisValue isKindOfClass:[NSNumber class]] && [otherValue isKindOfClass:[NSNumber class]], mismatchMessage);
    
    if (![thisValue isKindOfClass:[NSNumber class]] || ![otherValue isKindOfClass:[NSNumber class]]) {
        SPLogError(mismatchMessage);
        return @{ };
    }
    
    // Allow for floating point rounding variance
    double delta = [thisValue doubleValue] - [otherValue doubleValue];
    BOOL equal = (delta >= 0 && delta < 0.00001) || (delta < 0 && delta > -0.00001);
    
    if (equal) {
        return @{ };
    }
    
    // Construct the diff in the expected format
    return @{
        OP_OP : OP_REPLACE,
        OP_VALUE : otherValue
    };
}

- (id)applyDiff:(id)thisValue otherValue:(id)otherValue error:(NSError **)error {
    NSAssert([thisValue isKindOfClass:[NSNumber class]] && [otherValue isKindOfClass:[NSNumber class]],
            @"Simperium error: couldn't apply diff to ints because their classes weren't NSNumber");
    
    // Integer changes just replace the previous value by default
    // TODO: Not sure if this should be a copy or not...
    return otherValue;
}

- (NSDictionary *)transform:(id)thisValue otherValue:(id)otherValue oldValue:(id)oldValue error:(NSError **)error {
    // By default, don't transform anything, and take the local pending value
    thisValue = thisValue ?: [self defaultValue];
    return @{
        OP_OP       : OP_REPLACE,
        OP_VALUE    : thisValue
    };
}

@end
