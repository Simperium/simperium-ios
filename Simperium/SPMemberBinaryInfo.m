//
//  SPMemberBinaryInfo.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPMemberBinaryInfo.h"
#import "Simperium.h"
#import "SPBinaryManager.h"
#import "JSONKit.h"



@implementation SPMemberBinaryInfo

-(id)defaultValue
{
	return [@{} JSONString];
}

-(id)getValueFromDictionary:(NSDictionary *)dict key:(NSString *)key object:(id<SPDiffable>)object
{
    NSDictionary *payload = [dict objectForKey: key];
	if(payload == nil) {
		return nil;
	}

	// Ensure it gets faulted here and not across thread boundaries
	NSString *simperiumKey = [object.simperiumKey copy];
	NSString *bucketName = [[[object bucket] name] copy];

	dispatch_async(dispatch_get_main_queue(), ^{
		[self.binaryManager startDownloadIfNeeded:simperiumKey bucketName:bucketName attributeName:self.keyName];
	});

    return [payload JSONString];
}

-(NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue
{
	NSAssert([thisValue isKindOfClass:[NSString class]] && [otherValue isKindOfClass:[NSString class]],
			 @"Simperium error: couldn't diff ints because their classes weren't NSString");
	
    // Try a quick and dirty test instead first for performance
    if (([thisValue length] == [otherValue length]) || (thisValue == nil && otherValue == nil)) {
        return @{ };
	}
    
	// Construct the diff in the expected format
	return @{
				OP_OP		: OP_REPLACE,
				OP_VALUE	: otherValue
			};
}

-(id)applyDiff:(id)thisValue otherValue:(id)otherValue
{
	NSAssert([thisValue isKindOfClass:[NSString class]] && [otherValue isKindOfClass:[NSString class]],
			 @"Simperium error: couldn't apply diff to ints because their classes weren't NSString");
	
	// Integer changes just replace the previous value by default
	return otherValue;
}

@end

