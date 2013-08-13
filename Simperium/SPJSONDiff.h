//
//  SPJSONDiff.h
//  Simperium
//
//  Created by Andrew Mackenzie-Ross on 19/08/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NSDictionary SPDiffPolicy;
typedef NSDictionary SPDiff;

// main entrace method for diffing
extern SPDiff * SPDiffObjects(id obj1, id obj2, SPDiffPolicy *policy);
extern id SPApplyDiff(id object, SPDiff *diff);
extern SPDiff * SPTransformDiff(id source, SPDiff *diff1, SPDiff *diff2, SPDiffPolicy *policy);

typedef NSString SPStringDiff;
@interface NSString (SPJSONDiff)

// Returns a diff match patch string to get from the receiver to the target.
- (SPStringDiff *)sp_stringDiffToTargetString:(NSString *)targetString;

// Returns a new string after applying a diff string
- (NSString *)sp_stringByApplyingStringDiff:(SPStringDiff *)diff;

// Returns a new diff string that can be applied to a string that has already
// had stringDiff2 applied. The receiver should be the common ancestor of both.
- (NSString *)sp_stringDiffByTransformingStringDiff:(SPStringDiff *)stringDiff1 ontoStringDiff:(SPStringDiff *)stringDiff2;

@end

typedef NSNumber SPNumberDiff;

@interface NSNumber (SPJSONDiff)

- (SPNumberDiff *)sp_numberDiffToTargetNumber:(NSNumber *)number;

- (NSNumber *)sp_numberByApplyingNumberDiff:(SPNumberDiff *)numberDiff;

- (SPNumberDiff *)sp_numberDiffByTransformingNumberDiff:(SPNumberDiff *)numberDiff1 ontoNumberDiff:(SPNumberDiff *)numberDiff2;

@end

typedef NSString SPArrayDMPDiff;
typedef NSDictionary SPArrayDiff;

@interface NSArray (SPJSONDiff)

////////////////////////////////////////////////////////////////////////////////
// DiffMatchPatch Array Diffs (non recursive - does a replace on all objects in array)

- (SPArrayDMPDiff *)sp_arrayDMPDiffToTargetArray:(NSArray *)targetArray policy:(SPDiffPolicy *)diffPolicy;

// Returns the result of applying a diff to the receiver using diff match patch.
- (NSArray *)sp_arrayByApplyingArrayDMPDiff:(SPArrayDMPDiff *)arrayDMPDiff;

// Returns a transformed diff on top of another diff using diff match patch.
- (SPArrayDMPDiff *)sp_arrayDMPDiffByTransformingArrayDMPDiff:(SPArrayDMPDiff *)arrayDMPDiff1 ontoArrayDMPDiff:(SPArrayDMPDiff *)arrayDMPDiff2 policy:(SPDiffPolicy *)diffPolicy;

////////////////////////////////////////////////////////////////////////////////
// Full Array Diff
- (SPArrayDiff *)sp_arrayDiffToTargetArray:(NSArray *)targetArray policy:(SPDiffPolicy *)diffPolicy;

- (NSArray *)sp_arrayByApplyingArrayDiff:(SPArrayDiff *)arrayDiff;

- (SPArrayDiff *)sp_arrayDiffByTransformingArrayDiff:(SPArrayDiff *)arrayDiff1 ontoArrayDiff:(SPArrayDiff *)arrayDiff2 policy:(SPDiffPolicy *)diffPolicy;

@end

typedef NSDictionary SPObjectDiff;

@interface NSDictionary (SPJSONDiff)

- (SPObjectDiff *)sp_objectDiffToTargetObject:(NSDictionary *)targetObject policy:(SPDiffPolicy *)policy;
- (NSDictionary *)sp_objectByApplyingObjectDiff:(SPObjectDiff *)object;
- (SPObjectDiff *)sp_objectDiffByTransformingObjectDiff:(SPObjectDiff *)objectDiff1 ontoObjectDiff:(SPObjectDiff *)objectDiff2 policy:(SPDiffPolicy *)diffPolicy;

@end

