//
//  SPMemberDictionary.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 01-21-2021.
//  Copyright (c) 2021 Simperium. All rights reserved.
//

#import "SPMemberDictionary.h"
#import "SPLogger.h"



#pragma mark - Constants

static SPLogLevels logLevel = SPLogLevelsInfo;


#pragma mark SPMemberDictionary

@implementation SPMemberDictionary

- (id)defaultValue {
    return @{};
}

- (NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue {
    
    // Failsafe: In Release Builds, let's return an empty diff if the input is invalid
    NSString *mismatchMessage = @"Simperium error: couldn't diff dictionaries because their classes weren't NSDictionary";
    NSAssert([thisValue isKindOfClass:[NSDictionary class]] && [otherValue isKindOfClass:[NSDictionary class]], mismatchMessage);
    
    if (![thisValue isKindOfClass:[NSDictionary class]] || ![otherValue isKindOfClass:[NSDictionary class]]) {
        SPLogError(mismatchMessage);
        return @{ };
    }
    
    if ([thisValue isEqual:otherValue]) {
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
    
    // Failsafe
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

- (id)applyDiff:(id)thisValue otherValue:(id)otherValue error:(NSError **)error {
    NSAssert(thisValue == nil || [thisValue isKindOfClass:[NSDictionary class]], @"Simperium error: couldn't apply diff to double because its class wasn't NSDictionary");
    NSAssert(otherValue == nil || [otherValue isKindOfClass:[NSDictionary class]], @"Simperium error: couldn't apply diff to double because its class wasn't NSDictionary");

    // TODO: We should probably diff, eventually
    return otherValue;
}

- (NSDictionary *)transform:(id)thisValue otherValue:(id)otherValue oldValue:(id)oldValue error:(NSError **)error {
    // By default, don't transform anything, and take the local pending value
    return [NSDictionary dictionaryWithObjectsAndKeys:OP_REPLACE, OP_OP, thisValue, OP_VALUE, nil];
}

@end
