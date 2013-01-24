//
//  SPMemberFloat.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPMemberFloat.h"

@implementation SPMemberFloat

-(id)defaultValue {
	return [NSNumber numberWithFloat:0];
}

-(NSString *)defaultValueAsStringForSQL {
	return @"0";
}

-(NSString *)typeAsStringForSQL {
	return @"FLOAT";
}

-(NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue {
	NSAssert([thisValue isKindOfClass:[NSNumber class]] && [otherValue isKindOfClass:[NSNumber class]],
			 @"Simperium error: couldn't diff floats because their classes weren't NSNumber");
	
    // Allow for floating point rounding variance
    double delta = [thisValue floatValue] - [otherValue floatValue];
    BOOL equal = (delta >= 0 && delta < 0.00001) || (delta < 0 && delta > -0.00001);
    
	if (equal)
		return [NSDictionary dictionary];
    
	// Construct the diff in the expected format
	return [NSDictionary dictionaryWithObjectsAndKeys:
			OP_REPLACE, OP_OP,
			otherValue, OP_VALUE, nil];
}

-(id)applyDiff:(id)thisValue otherValue:(id)otherValue {
	NSAssert([thisValue isKindOfClass:[NSNumber class]] && [otherValue isKindOfClass:[NSNumber class]],
			 @"Simperium error: couldn't apply diff to floats because their classes weren't NSNumber");
	
	// Integer changes just replace the previous value by default
	// TODO: Not sure if this should be a copy or not...
	return otherValue;
}

//-(id)sqlLoadWithStatement:(sqlite3_stmt *)statement queryPosition:(int)position
//{
//	return [NSNumber numberWithDouble: sqlite3_column_double(statement, position)];
//}
//
//-(void)sqlBind:(id)data withStatement:(sqlite3_stmt *)statement queryPosition:(int)position
//{
//	sqlite3_bind_double(statement, position, [data doubleValue]);
//}


@end
