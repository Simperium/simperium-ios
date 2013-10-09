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



@implementation SPMemberBinaryInfo

-(id)defaultValue
{
	return @"";
}

-(id)getValueFromDictionary:(NSDictionary *)dict key:(NSString *)key object:(id<SPDiffable>)object
{
    NSString *filename = [dict objectForKey: key];
    
    // Don't have a filename yet
    if (filename == nil) {
        return nil;
	}
    
    // The value is an entity key; return the entity itself instead (or nil if it's not received yet)
    BOOL downloaded = NO; //[self.binaryManager binaryExists: filename];
    id value = downloaded ? filename : nil;
    
    // If it's not here yet, flag it so the reference can be resolved when it finishes downloading
    if (!downloaded) {
        NSString *objectKey = [object.simperiumKey copy]; // ensure it gets faulted here and not across thread boundaries
        NSString *bucketName = [[[object bucket] name] copy];
		
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.binaryManager addPendingReferenceToFile:filename
                                             fromKey:objectKey
                                          bucketName:bucketName
                                          attributeName:self.keyName];
        });
    }
    return value;    
}

-(NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue
{
	NSAssert([thisValue isKindOfClass:[NSString class]] && [otherValue isKindOfClass:[NSString class]],
			 @"Simperium error: couldn't diff ints because their classes weren't NSString");
	
    // Try a quick and dirty test instead first for performance
    if ([thisValue length] == [otherValue length] || (thisValue == nil && otherValue == nil)) {
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

