//
//  SPJSONDiff.m
//  Simperium
//
//  Created by Andrew Mackenzie-Ross on 19/08/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPJSONDiff.h"

#import "DiffMatchPatch.h"
#import "SPMember.h"
#import "JSONKit+Simperium.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_INFO;


static NSString * const SPPolicyItemKey = @"item";
static NSString * const SPPolicyAttributesKey = @"attributes";
static NSString * const SPOperationTypeKey = @"otype";

static DiffMatchPatch * SPDiffMatchPatch();

NSString * SPOperationTypeForClass(Class class);

SPDiff * SPDiffObjects(id obj1, id obj2, NSDictionary *policy)
{
    if (!obj1 && !obj2) return nil;
    if ([obj1 isEqual:obj2]) return nil;
    if (!obj1 && obj2) return @{ OP_OP: OP_OBJECT_ADD, OP_VALUE: obj2 };
    if (!obj2 && obj1) return @{ OP_OP: OP_OBJECT_REMOVE };
    
    // Allow for floating point rounding variance
    if ([obj1 isKindOfClass:[NSNumber class]] && [obj2 isKindOfClass:[NSNumber class]]) {
        double delta = [obj1 doubleValue] - [obj2 doubleValue];
        if (ABS(delta) < 0.00001) return nil;
    }

    Class class = [obj1 class] ?: [obj2 class];
    NSString *operationType = policy[SPPolicyAttributesKey][SPOperationTypeKey] ?: SPOperationTypeForClass(class);
    
    if ([operationType isEqual:OP_REPLACE]) return @{ OP_OP: OP_REPLACE, OP_VALUE: obj2 }; // prematue-optimization
    if ([operationType isEqual:OP_STRING] && [obj1 isKindOfClass:[NSString class]] && [obj2 isKindOfClass:[NSString class]]) return @{ OP_OP: OP_STRING, OP_VALUE: [(NSString *)obj1 sp_stringDiffToTargetString:(NSString *)obj2] };
    if ([operationType isEqual:OP_OBJECT] && [obj1 isKindOfClass:[NSDictionary class]] && [obj2 isKindOfClass:[NSDictionary class]]) return @{ OP_OP: OP_OBJECT, OP_VALUE: [(NSDictionary *)obj1 sp_objectDiffToTargetObject:(NSDictionary *)obj2 policy:policy] };
    if ([operationType isEqual:OP_LIST] && [obj1 isKindOfClass:[NSArray class]] && [obj2 isKindOfClass:[NSArray class]]) return @{ OP_OP: OP_LIST, OP_VALUE: [(NSArray *)obj1 sp_arrayDiffToTargetArray:(NSArray *)obj2 policy:policy] };
    if ([operationType isEqual:OP_LIST_DMP ] && [obj1 isKindOfClass:[NSArray class]] && [obj2 isKindOfClass:[NSArray class]]) return @{ OP_OP: OP_LIST_DMP, OP_VALUE: [(NSArray *)obj1 sp_arrayDMPDiffToTargetArray:(NSArray *)obj2 policy:policy] };
    if ([operationType isEqual:OP_INTEGER] && [obj1 isKindOfClass:[NSNumber class]] && [obj2 isKindOfClass:[NSNumber class]]) return @{ OP_OP: OP_INTEGER, OP_VALUE: [(NSNumber *)obj1 sp_numberDiffToTargetNumber:(NSNumber *)obj2] };
    return @{ OP_OP: OP_REPLACE, OP_VALUE: obj2 };

}

NSString * SPOperationTypeForClass(Class class)
{

    if ([class isSubclassOfClass:[NSDictionary class]]) return OP_OBJECT;
    if ([class isSubclassOfClass:[NSString class]]) return OP_STRING;
    return OP_REPLACE;
}


id SPApplyDiff(id object, SPDiff *diff)
{
    NSCParameterAssert(diff);
    
    NSString *op = diff[OP_OP];
    id value = diff[OP_VALUE];
    if ([op isEqual:OP_OBJECT_REMOVE]) return nil;
        if ([op isEqual:OP_REPLACE] || [op isEqual:OP_OBJECT_ADD]) return value;
    if ([op isEqual:OP_STRING] && [object isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) return [(NSString *)object sp_stringByApplyingStringDiff:value];
    if ([op isEqual:OP_OBJECT] && [object isKindOfClass:[NSDictionary class]] && [value isKindOfClass:[NSDictionary class]]) return [(NSDictionary *)object sp_objectByApplyingObjectDiff:value];
    if ([op isEqual:OP_LIST] && [object isKindOfClass:[NSArray class]] && [value isKindOfClass:[NSDictionary class]]) return [(NSArray *)object sp_arrayByApplyingArrayDiff:value];
    if ([op isEqual:OP_LIST_DMP] && [object isKindOfClass:[NSArray class]] && [value isKindOfClass:[NSString class]]) return [(NSArray *)object sp_arrayByApplyingArrayDMPDiff:value];
    if ([op isEqual:OP_INTEGER] && [object isKindOfClass:[NSNumber class]] && [value isKindOfClass:[NSNumber class]]) return [(NSNumber *)object sp_numberByApplyingNumberDiff:value];
    DDLogCError(@"Unable to apply diff (%@) to object (%@)",diff, object);
    return object;
}

SPDiff * SPTransformDiff(id source, SPDiff *aop, SPDiff *bop, SPDiffPolicy *policy)
{
    NSCParameterAssert(aop && bop);

    NSString *aop_op = aop[OP_OP], *bop_op = bop[OP_OP];
    if ([aop_op isEqual:OP_OBJECT_ADD] && [bop_op isEqual:OP_OBJECT_ADD]) {
        if ([aop[OP_VALUE] isEqual:bop[OP_VALUE]]) return nil;
        return SPDiffObjects(aop[OP_VALUE], bop[OP_VALUE], policy);
    }
    if ([aop_op isEqual:OP_OBJECT_REMOVE] && [bop_op isEqual:OP_OBJECT_REMOVE]) return nil;
    if (![aop_op isEqual:OP_OBJECT_ADD] && [bop_op isEqual:OP_OBJECT_REMOVE]) {
        id valueAfterA = SPApplyDiff(source, aop);
        if (!valueAfterA) return nil;
        return @{ OP_OP: OP_OBJECT_ADD, OP_VALUE: valueAfterA };
    }
    if ([aop_op isEqual:bop_op]) {
        if ([aop_op isEqual:OP_STRING]) {
            NSString *transformedString = [(NSString *)source sp_stringDiffByTransformingStringDiff:aop[OP_VALUE] ontoStringDiff:bop[OP_VALUE]];
            if (!transformedString) return nil;
            return @{ OP_OP: OP_STRING, OP_VALUE: transformedString };
        }
        if ([aop_op isEqual:OP_OBJECT]) return @{ OP_OP: OP_OBJECT, OP_VALUE: [(NSDictionary *)source sp_objectDiffByTransformingObjectDiff:aop[OP_VALUE] ontoObjectDiff:bop[OP_VALUE] policy:policy] };
        if ([aop_op isEqual:OP_LIST]) return @{ OP_OP: OP_LIST, OP_VALUE: [(NSArray *)source sp_arrayDiffByTransformingArrayDiff:aop[OP_VALUE] ontoArrayDiff:bop[OP_VALUE] policy:policy] };
        if ([aop_op isEqual:OP_LIST_DMP]) return @{ OP_OP: OP_LIST_DMP, OP_VALUE: [(NSArray *)source sp_arrayDMPDiffByTransformingArrayDMPDiff:aop[OP_VALUE] ontoArrayDMPDiff:bop[OP_VALUE] policy:policy] };
        if ([aop_op isEqual:OP_INTEGER]) return @{ OP_OP: OP_INTEGER, OP_VALUE: [(NSNumber *)source sp_numberDiffByTransformingNumberDiff:aop[OP_VALUE] ontoNumberDiff:bop[OP_VALUE]] };
    }

    return nil;
}

#pragma mark - Object Diff

@implementation NSDictionary (SPJSONDiff)

- (SPObjectDiff *)sp_objectDiffToTargetObject:(NSDictionary *)targetObject policy:(NSDictionary *)policy
{
    NSMutableDictionary *diffs = [[NSMutableDictionary alloc] init];

    NSDictionary *a = self, *b = targetObject;

    for (NSString *key in a) {
        NSDictionary *elementPolicy = policy[SPPolicyAttributesKey][key];
        if (!b[key]) {
            diffs[key] = @{ OP_OP: OP_OBJECT_REMOVE };
            continue;
        }
        NSDictionary *diff = SPDiffObjects(a[key], b[key], elementPolicy);
        if (diff) diffs[key] = diff;
    }
    for (NSString *key in b) {
        if (!a[key]) {
            diffs[key] = @{ OP_OP: OP_OBJECT_ADD, OP_VALUE: b[key] };
        }
    }
    
    return diffs;
}

- (NSDictionary *)sp_objectByApplyingObjectDiff:(SPObjectDiff *)diff
{
    NSMutableDictionary *newObject = [self mutableCopy];
    for (NSString *key in diff) {
        id newValue = SPApplyDiff(self[key], diff[key]);
        if (newValue) {
            newObject[key] = newValue;
        } else {
            [newObject removeObjectForKey:key];
        }
    }
    return newObject;
}

- (NSDictionary *)sp_objectDiffByTransformingObjectDiff:(SPObjectDiff *)ad ontoObjectDiff:(SPObjectDiff *)bd policy:(SPDiffPolicy *)diffPolicy
{
    NSMutableDictionary *ad_new = [ad mutableCopy];
    for (NSString *key in ad) {
        if (!bd[key]) continue;
        
        NSDictionary *elementPolicy = diffPolicy[SPPolicyAttributesKey][key];
        SPObjectDiff *diff = SPTransformDiff(self[key], ad[key], bd[key], elementPolicy);
        if (diff) {
            ad_new[key] = diff;
        } else {
            [ad_new removeObjectForKey:key];
        }
    }
    return ad_new;
}

@end

#pragma mark - String Diff

@implementation NSString (SPJSONDiff)

- (SPStringDiff *)sp_stringDiffToTargetString:(NSString *)targetString
{
    DiffMatchPatch *dmp = SPDiffMatchPatch();
    NSMutableArray *diffs = [dmp diff_mainOfOldString:self andNewString:targetString];
    if ([diffs count] > 2) {
		[dmp diff_cleanupSemantic:diffs];
		[dmp diff_cleanupEfficiency:diffs];
	}
    if ([diffs count] == 0 || [dmp diff_levenshtein:diffs] == 0) return nil;
    return [dmp diff_toDelta:diffs];
}

- (NSString *)sp_stringByApplyingStringDiff:(SPStringDiff *)diff
{
    if (diff == nil) return [self copy];
    DiffMatchPatch *dmp = SPDiffMatchPatch();
    NSError __autoreleasing *error = nil;
    NSMutableArray *diffs = [dmp diff_fromDeltaWithText:self andDelta:diff error:&error];
    if (error) {
        return nil;
    }
    NSMutableArray *patches = [dmp patch_makeFromDiffs:diffs];
    
    // the first object is the patched string.
    return [dmp patch_apply:patches toString:self][0];
}

- (SPStringDiff *)sp_stringDiffByTransformingStringDiff:(NSString *)stringDiff1 ontoStringDiff:(NSString *)stringDiff2
{
    DiffMatchPatch *dmp = SPDiffMatchPatch();
    NSError __autoreleasing *error = nil;
    NSMutableArray *diff1Diffs = [dmp diff_fromDeltaWithText:self andDelta:stringDiff1 error:&error];
    if (error) {
        return nil;
    }
    NSMutableArray *diff2Diffs = [dmp diff_fromDeltaWithText:self andDelta:stringDiff2 error:&error];
    if (error) {
        return nil;
    }
    NSMutableArray *diff1Patches = [dmp patch_makeFromOldString:self andDiffs:diff1Diffs];
    NSMutableArray *diff2Patches = [dmp patch_makeFromOldString:self andDiffs:diff2Diffs];
    NSString *resultFromDiff2 = [dmp patch_apply:diff2Patches toString:self][0];
    NSString *combinedResult = [dmp patch_apply:diff1Patches toString:resultFromDiff2][0];
    
    NSMutableArray *diffsFromDiff2ToCombinedResult = [dmp diff_mainOfOldString:resultFromDiff2 andNewString:combinedResult];
    if ([diffsFromDiff2ToCombinedResult count] > 2) {
		[dmp diff_cleanupSemantic:diffsFromDiff2ToCombinedResult];
		[dmp diff_cleanupEfficiency:diffsFromDiff2ToCombinedResult];
	}

    if ([diffsFromDiff2ToCombinedResult count] == 0 || [dmp diff_levenshtein:diffsFromDiff2ToCombinedResult] == 0) return nil;
    return [dmp diff_toDelta:diffsFromDiff2ToCombinedResult];
}

@end

#pragma mark - Integer Diff

@implementation NSNumber (SPJSONDiff)

- (SPNumberDiff *)sp_numberDiffToTargetNumber:(NSNumber *)number
{
    return @(number.doubleValue - self.doubleValue);
}

- (NSNumber *)sp_numberByApplyingNumberDiff:(SPNumberDiff *)numberDiff
{
    return @(self.doubleValue + numberDiff.doubleValue);
}

- (SPNumberDiff *)sp_numberDiffByTransformingNumberDiff:(SPNumberDiff *)numberDiff1 ontoNumberDiff:(SPNumberDiff *)numberDiff2
{
    double resultFromDiff2 = self.doubleValue + numberDiff2.doubleValue;
    double combinedResult = resultFromDiff2 + numberDiff1.doubleValue;
    double diffFromDiff2ToCombinedResult = combinedResult - resultFromDiff2;
    return @(diffFromDiff2ToCombinedResult);
}

@end

#pragma mark - List Diffs

@implementation NSArray (SPJSONDiff)

#pragma mark Diff Match Patch

- (SPArrayDMPDiff *)sp_arrayDMPDiffToTargetArray:(NSArray *)targetArray policy:(SPDiffPolicy *)diffPolicy
{
	NSParameterAssert(targetArray);
	return [self sp_diffWithArray:targetArray diffMatchPatch:SPDiffMatchPatch()];
}

- (NSArray *)sp_arrayByApplyingArrayDMPDiff:(SPArrayDMPDiff *)arrayDMPDiff
{
	NSParameterAssert(arrayDMPDiff);
    DiffMatchPatch *dmp = SPDiffMatchPatch();
	
	NSString *newLineSeparatedJSONString = [self sp_newLineSeparatedJSONString];
	
	NSError __autoreleasing *error = nil;
	NSMutableArray *diffs = [dmp diff_fromDeltaWithText:newLineSeparatedJSONString andDelta:arrayDMPDiff error:&error];
    
	if (error) {
		[NSException raise:NSInternalInconsistencyException format:@"Simperium: Error creating diff from diff with text %@ and diff %@ due to error %@ in %s.", newLineSeparatedJSONString, arrayDMPDiff, error, __PRETTY_FUNCTION__];
	}
    
	NSMutableArray *patches = [dmp patch_makeFromDiffs:diffs];
	NSString *updatedNewlineSeparatedString = [dmp patch_apply:patches toString:newLineSeparatedJSONString][0];
	
	return [NSArray sp_arrayFromNewLineSeparatedJSONString:updatedNewlineSeparatedString];
}

- (SPArrayDMPDiff *)sp_arrayDMPDiffByTransformingArrayDMPDiff:(SPArrayDMPDiff *)arrayDMPDiff1 ontoArrayDMPDiff:(SPArrayDMPDiff *)arrayDMPDiff2 policy:(SPDiffPolicy *)diffPolicy
{
	NSParameterAssert(arrayDMPDiff1); NSParameterAssert(arrayDMPDiff2);
    DiffMatchPatch *dmp = SPDiffMatchPatch();

	NSString *sourceText = [self sp_newLineSeparatedJSONString];
	
	NSError __autoreleasing *error = nil;
	NSMutableArray *diffs1 = [dmp diff_fromDeltaWithText:sourceText andDelta:arrayDMPDiff1 error:&error];
	if (error) [NSException raise:NSInternalInconsistencyException format:@"Simperium: Error creating diff from diff with text %@ and diff %@ due to error %@ in %s.", sourceText, arrayDMPDiff1, error, __PRETTY_FUNCTION__];
    NSMutableArray *diffs2 = [dmp diff_fromDeltaWithText:sourceText andDelta:arrayDMPDiff2 error:&error];
	if (error) [NSException raise:NSInternalInconsistencyException format:@"Simperium: Error creating diff from diff with text %@ and diff %@ due to error %@ in %s.", sourceText, arrayDMPDiff2, error, __PRETTY_FUNCTION__];
	
    NSMutableArray *patches1 = [dmp patch_makeFromDiffs:diffs1];
    NSMutableArray *patches2 = [dmp patch_makeFromDiffs:diffs2];

	NSString *diff2Text = [dmp patch_apply:patches2 toString:sourceText][0];
	NSString *diff2And1Text = [dmp patch_apply:patches1 toString:diff2Text][0];
	
	if ([diff2And1Text isEqualToString:diff2Text]) return @""; // no-op diff
	
	NSMutableArray *diffs = [dmp diff_lineModeFromOldString:diff2Text andNewString:diff2And1Text deadline:0];
	
	return [dmp diff_toDelta:diffs];
}


- (NSString *)sp_diffWithArray:(NSArray *)obj diffMatchPatch:(DiffMatchPatch *)dmp
{
	NSParameterAssert(obj); NSParameterAssert(dmp);
	
	NSString *nljs1 = [self sp_newLineSeparatedJSONString];
	NSString *nljs2 = [obj sp_newLineSeparatedJSONString];
	
    
	NSArray *b = [dmp diff_linesToCharsForFirstString:nljs1 andSecondString:nljs2];
	NSString *text1 = (NSString *)[b objectAtIndex:0];
	NSString *text2 = (NSString *)[b objectAtIndex:1];
	NSMutableArray *linearray = (NSMutableArray *)[b objectAtIndex:2];
	
	NSMutableArray *diffs = nil;
	@autoreleasepool {
		diffs = [dmp diff_mainOfOldString:text1 andNewString:text2 checkLines:NO deadline:0];
	}
	
	// Convert the diff back to original text.
	[dmp diff_chars:diffs toLines:linearray];
	// Eliminate freak matches (e.g. blank lines)
	[dmp diff_cleanupSemantic:diffs];
	
	// Removing "-0	" as this is a no-op operations that crashes the apply patch method.
	return [[dmp diff_toDelta:diffs] stringByReplacingOccurrencesOfString:@"-0	" withString:@""];
}

- (NSString *)sp_newLineSeparatedJSONString
{
	// Create a new line separated list of JSON objects in an array.
	// e.g.
	// { "a" : 1, "c" : "3" }\n{ "b" : 2 }\n
	//
	NSMutableString *JSONString = [[NSMutableString alloc] init];
	for (id object in self) {
		if (object == (id)kCFBooleanTrue) {
			[JSONString appendString:@"true\n"];
		} else if (object == (id)kCFBooleanFalse) {
			[JSONString appendString:@"false\n"];
		} else if ([object isKindOfClass:[NSNumber class]]) {
			[JSONString appendFormat:@"%@\n",object];
		} else if ([object isKindOfClass:[NSString class]]) {
			[JSONString appendFormat:@"\"%@\"\n",object];
		} else if (object == [NSNull null]) {
			[JSONString appendString:@"null\n"];
		} else if ([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSDictionary class]]) {
			[JSONString appendFormat:@"%@\n",[[object sp_JSONString] stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
		} else {
			[NSException raise:NSInternalInconsistencyException format:@"Simperium: Cannot create diff match patch with non-json object %@ in %s",object,__PRETTY_FUNCTION__];
		}
	}
	
	// Remove final \n character from string
	if ([JSONString isEqualToString:@""]) return JSONString;
	return [JSONString substringToIndex:[JSONString length] - 1];
}

+ (NSArray *)sp_arrayFromNewLineSeparatedJSONString:(NSString *)string
{
	NSParameterAssert(string);
	
	NSArray *JSONStrings = [string componentsSeparatedByString:@"\n"];
	// Remove any lines with nothing on them.
	JSONStrings = [JSONStrings filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
		return ![evaluatedObject isEqual:@""];
	}]];
	NSString *JSONArrayString = [NSString stringWithFormat:@"[ %@ ]", [JSONStrings componentsJoinedByString:@", "]];
	return [JSONArrayString sp_objectFromJSONString];
}

#pragma mark - Full Array Diff

- (SPArrayDiff *)sp_arrayDiffToTargetArray:(NSArray *)obj2 policy:(SPDiffPolicy *)diffPolicy
{
    NSDictionary *itemPolicy = diffPolicy[SPPolicyItemKey];
    
    if ([self isEqualToArray:obj2]) return @{};
	NSArray *obj1 = self;
    
	NSMutableDictionary *diffs = [[NSMutableDictionary alloc] init];
    
	NSInteger prefixCount = [obj1 sp_countOfObjectsCommonWithArray:obj2 options:0];
	obj1 = [obj1 subarrayWithRange:NSMakeRange(prefixCount, [obj1 count] - prefixCount)];
	obj2 = [obj2 subarrayWithRange:NSMakeRange(prefixCount, [obj2 count] - prefixCount)];
    
	NSInteger suffixCount = [obj1 sp_countOfObjectsCommonWithArray:obj2 options:NSEnumerationReverse];
	obj1 = [obj1 subarrayWithRange:NSMakeRange(0, [obj1 count] - suffixCount)];
	obj2 = [obj2 subarrayWithRange:NSMakeRange(0, [obj2 count] - suffixCount)];
    
	NSInteger obj1Count = [obj1 count];
	NSInteger obj2Count = [obj2 count];
	for (int i = 0; i < MAX(obj1Count, obj2Count); i++) {
		if (i < obj1Count && i < obj2Count) {
                SPDiff *diff = SPDiffObjects(obj1[i], obj2[i], itemPolicy);
                if (diff)	diffs[[@(i + prefixCount) stringValue]] = diff;
		} else if (i < obj1Count) {
			diffs[[@(i + prefixCount) stringValue]] = @{ OP_OP: OP_LIST_DELETE };
		} else if (i < obj2Count) {
			diffs[[@(i + prefixCount) stringValue]] = @{ OP_OP: OP_LIST_INSERT, OP_VALUE: obj2[i] };
		}
	}
    
	return diffs;
}

- (NSArray *)sp_arrayByApplyingArrayDiff:(SPArrayDiff *)arrayDiff {
    NSMutableArray *array = [self mutableCopy];
    
    NSArray *indexKeys = [[arrayDiff allKeys] sortedArrayWithOptions:0 usingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [@([obj1 intValue]) compare:@([obj2 intValue])];
    }];
        
    NSMutableIndexSet *indexesToReplace = [[NSMutableIndexSet alloc] init];
	NSMutableArray *replacementObjects = [[NSMutableArray alloc] init];
	NSMutableIndexSet *indexesToRemove = [[NSMutableIndexSet alloc] init];
	NSMutableIndexSet *indexesToInsert = [[NSMutableIndexSet alloc] init];
	NSMutableArray *insertedObjects = [[NSMutableArray alloc] init];

    for (NSString *indexKey in indexKeys) {
        NSDictionary *elementDiff = arrayDiff[indexKey];
        NSInteger index = [indexKey intValue];
        
        NSString *operation = [elementDiff objectForKey:OP_OP];
        
        if ([operation isEqualToString:OP_LIST_DELETE]) {
			[indexesToRemove addIndex:index];
		} else if ([operation isEqualToString:OP_LIST_INSERT]) {
			[insertedObjects addObject:[elementDiff objectForKey:OP_VALUE]];
			[indexesToInsert addIndex:index];
		} else {
            id sourceValue = array[index];
            id diffedValue = SPApplyDiff(sourceValue, elementDiff);
            [replacementObjects addObject:diffedValue];
            [indexesToReplace addIndex:index];
        }
        
    }
    
	[array replaceObjectsAtIndexes:indexesToReplace withObjects:replacementObjects];
	[array removeObjectsAtIndexes:indexesToRemove];
	[array insertObjects:insertedObjects atIndexes:indexesToInsert];
    
	return array;
}

- (NSDictionary *)sp_arrayDiffByTransformingArrayDiff:(SPArrayDiff *)ad ontoArrayDiff:(SPArrayDiff *)bd policy:(SPDiffPolicy *)diffPolicy
{
    NSMutableArray *b_inserts = [[NSMutableArray alloc] init];
    NSMutableArray *b_deletes = [[NSMutableArray alloc] init];
    
    for (id indexKey in bd) {
        // This will convert strings or numbers to NSNumbers.
        NSInteger index = [indexKey integerValue];
        NSDictionary *change = bd[indexKey];
        if ([change[OP_OP] isEqual:OP_LIST_INSERT]) [b_inserts addObject:@(index)];
        if ([change[OP_OP] isEqual:OP_LIST_DELETE]) [b_deletes addObject:@(index)];
    }
    
    NSMutableDictionary *ad_new = [[NSMutableDictionary alloc] init];

    NSInteger lastIndex = 0, lastShift = 0;
    for (id indexKey in ad) {
        // This will convert strings or numbers to NSNumbers.
        NSInteger index = [indexKey integerValue];
        NSInteger shift_r = [[b_inserts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self < %i",index]] count];
        NSInteger shift_l = [[b_deletes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self < %i",index]] count];
        NSInteger shiftedIndex = (lastIndex + 1 == index ? index + lastShift : index + shift_r - shift_l);
        lastIndex = shiftedIndex;
        lastShift = shift_r - shift_l;
        
        NSDictionary *op = ad[indexKey];
        NSString *shiftedIndexKey = [@(shiftedIndex) stringValue];
        ad_new[shiftedIndexKey] = op;
        NSDictionary *bOp = bd[shiftedIndexKey];
        if (bOp) {
            if ([op[OP_OP] isEqual:OP_LIST_INSERT] && [bd[shiftedIndexKey][OP_OP] isEqual:OP_LIST_INSERT]) continue;
            if ([op[OP_OP] isEqual:OP_LIST_DELETE]) {
                if ([bOp[OP_OP] isEqual:OP_LIST_DELETE]) [ad_new removeObjectForKey:shiftedIndexKey];
                continue;
            }
            if ([bOp[OP_OP] isEqual:OP_LIST_DELETE]) {
                if ([op[OP_OP] isEqual:OP_REPLACE]) ad_new[shiftedIndexKey] = @{ OP_OP: OP_LIST_INSERT, OP_VALUE: op[OP_VALUE] };
                if (![op[OP_OP] isEqual:OP_LIST_INSERT]) {
                        ad_new[shiftedIndexKey] = @{ OP_OP: OP_LIST_INSERT, OP_VALUE: SPApplyDiff(self[index], op) };
                }
                continue;
            }
            SPDiff *diff = SPTransformDiff(self[shiftedIndex], op, bd[shiftedIndexKey], diffPolicy[SPPolicyItemKey]);
            if (diff) {
              ad_new[shiftedIndexKey] = diff;  
            } else {
                [ad_new removeObjectForKey:shiftedIndexKey];
            }
        }

    }
    
    return ad_new;
    
}


- (NSInteger)sp_countOfObjectsCommonWithArray:(NSArray *)b options:(NSEnumerationOptions)options
{
	NSAssert(options ^ NSEnumerationConcurrent, @"%s doesn't support NSEnumerationConcurrent",__PRETTY_FUNCTION__);
	__block NSInteger count = 0;
	NSArray *a = self;
	NSInteger shift = (options & NSEnumerationReverse) ? [b count] - [a count] : 0;
	[self enumerateObjectsWithOptions:options usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSInteger idxIntoB = idx + shift;
		if (idxIntoB >= [b count] || idxIntoB < 0 || ![obj isEqual:b[idxIntoB]]) {
			*stop = YES;
		} else {
			count++;
		}
	}];

	return count;
}

@end

#pragma - Utilites



DiffMatchPatch * SPDiffMatchPatch()
{
    static DiffMatchPatch *dmp = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dmp = [[DiffMatchPatch alloc] init];
    });
    return dmp;
}