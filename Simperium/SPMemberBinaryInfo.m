//
//  SPMemberBinaryInfo.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPMemberBinaryInfo.h"
#import "Simperium.h"
#import "SPBinaryManager+Internals.h"
#import "JSONKit.h"
#import "DiffMatchPatch.h"
#import "NSArray+Simperium.h"


NSString* const SPMemberBinaryInfoSuffix = @"Info";


@implementation SPMemberBinaryInfo

-(id)defaultValue
{
	return [@{} JSONString];
}

-(id)stringValueFromDict:(id)value {
    if ([value length] == 0) {
        return [[self defaultValue] objectFromJSONString];
	} else {
		return [value objectFromJSONString];
	}
}

-(id)getValueFromDictionary:(NSDictionary *)dict key:(NSString *)key object:(id<SPDiffable>)object
{
    NSDictionary *binaryInfo = [dict objectForKey: key];
	if(binaryInfo == nil || binaryInfo.count == 0) {
		return nil;
	}
	
	// Ensure it gets faulted here and not across thread boundaries
	NSString *simperiumKey = [object.simperiumKey copy];
	NSString *bucketName = [[[object bucket] name] copy];

	dispatch_async(dispatch_get_main_queue(), ^{
		[object.bucket.binaryManager downloadIfNeeded:bucketName simperiumKey:simperiumKey dataKey:self.dataKey infoKey:self.infoKey binaryInfo:binaryInfo];
	});
	
    return [binaryInfo JSONString];
}

-(void)setValue:(id)value forKey:(NSString *)key inDictionary:(NSMutableDictionary *)dict {
    id convertedValue = [self stringValueFromDict: value];
    [dict setValue:convertedValue forKey:key];
}

-(NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue
{
	NSAssert([thisValue isKindOfClass:[NSString class]] && [otherValue isKindOfClass:[NSString class]],
			 @"Simperium error: couldn't diff ints because their classes weren't NSString");
	
    // Try a quick and dirty test instead first for performance
    if (([thisValue length] == [otherValue length]) || (thisValue == nil && otherValue == nil)) {
        return @{ };
	// Construct the diff in the expected format
	} else {
		return @{
					OP_OP		: OP_REPLACE,
					OP_VALUE	: [self stringValueFromDict:otherValue]
				};
	}
}

-(id)applyDiff:(id)thisValue otherValue:(id)otherValue
{	
	NSAssert([thisValue isKindOfClass:[NSString class]] && [otherValue isKindOfClass:[NSString class]],
			 @"Simperium error: couldn't apply diff to ints because their classes weren't NSString");

	// Integer changes just replace the previous value by default
	return otherValue;
}

-(NSString*)dataKey
{
	NSInteger length = SPMemberBinaryInfoSuffix.length;
	NSRange range = { self.keyName.length - length, length };
	
	NSAssert([[self.keyName substringWithRange:range] isEqualToString:SPMemberBinaryInfoSuffix],
			 @"Simperium error: Binary Metadata Attribute should be named: [attributeName]Info");
	
	return [self.keyName stringByReplacingCharactersInRange:range withString:@""];
}

-(NSString *)infoKey
{
	return self.keyName;
}

@end
