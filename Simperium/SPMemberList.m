//
//  SPMemberList.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPMemberList.h"
#import "JSONKit.h"

@implementation SPMemberList

-(id)defaultValue {
	return @"[]";
}

-(id)getValueFromDictionary:(NSDictionary *)dict key:(NSString *)key object:(id<SPDiffable>)object {
    id value = [dict objectForKey: key];
    value = [self fromJSON: value];
    return value;
}

-(void)setValue:(id)value forKey:(NSString *)key inDictionary:(NSMutableDictionary *)dict {
    id convertedValue = [self toJSON: value];
    [dict setValue:convertedValue forKey:key];
}

-(id)toJSON:(id)value {
    if ([value length] == 0)
        return [[self defaultValue] objectFromJSONString];
	return [value objectFromJSONString];
}

-(id)fromJSON:(id)value {
	return [value JSONString];
}

-(NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue {
	NSAssert([thisValue isKindOfClass:[NSString class]] && [otherValue isKindOfClass:[NSString class]],
			 @"Simperium error: couldn't diff dates because their classes weren't NSString");
    
	// TODO: proper list diff; for now just replace
    
    if ([thisValue isEqualToString: otherValue])
		return [NSDictionary dictionary];
    
	// Construct the diff in the expected format
	return [NSDictionary dictionaryWithObjectsAndKeys:
			OP_REPLACE, OP_OP,
			[self toJSON: otherValue], OP_VALUE, nil];
}

-(id)applyDiff:(id)thisValue otherValue:(id)otherValue {
    // TODO: proper list diff, including transform
	// Expect dates in Number format
	//NSAssert([thisValue isKindOfClass:[NSNumber class]] && [otherValue isKindOfClass:[NSNumber class]],
	//		 @"Simperium error: couldn't diff dates because their classes weren't NSNumber (NSDate not supported directly)");
	
	// Date changes replaces the previous value by default (like ints)
	
	// TODO: Not sure if this should be a copy or not
	return otherValue;
}

@end
