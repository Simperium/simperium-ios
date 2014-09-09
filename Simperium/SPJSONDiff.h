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
extern id SPApplyDiff(id object, SPDiff *diff, NSError *__autoreleasing *error);
extern SPDiff * SPTransformDiff(id source, SPDiff *diff1, SPDiff *diff2, SPDiffPolicy *policy, NSError *__autoreleasing *error);

typedef NSString SPStringDiff;
@interface NSString (SPJSONDiff)

// Returns a diff match patch string to get from the receiver to the target.
- (SPStringDiff *)sp_stringDiffToTargetString:(NSString *)targetString;

// Returns a new string after applying a diff string
- (NSString *)sp_stringByApplyingStringDiff:(SPStringDiff *)diff error:(NSError *__autoreleasing *)error;

// Returns a new diff string that can be applied to a string that has already
// had stringDiff2 applied. The receiver should be the common ancestor of both.
- (SPStringDiff *)sp_stringDiffByTransformingStringDiff:(SPStringDiff *)stringDiff1 ontoStringDiff:(SPStringDiff *)stringDiff2 error:(NSError *__autoreleasing *)error;

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
- (NSArray *)sp_arrayByApplyingArrayDMPDiff:(SPArrayDMPDiff *)arrayDMPDiff error:(NSError *__autoreleasing *)error;

// Returns a transformed diff on top of another diff using diff match patch.
- (SPArrayDMPDiff *)sp_arrayDMPDiffByTransformingArrayDMPDiff:(SPArrayDMPDiff *)arrayDMPDiff1 ontoArrayDMPDiff:(SPArrayDMPDiff *)arrayDMPDiff2 policy:(SPDiffPolicy *)diffPolicy error:(NSError *__autoreleasing *)error;

////////////////////////////////////////////////////////////////////////////////
// Full Array Diff
- (SPArrayDiff *)sp_arrayDiffToTargetArray:(NSArray *)targetArray policy:(SPDiffPolicy *)diffPolicy;

- (NSArray *)sp_arrayByApplyingArrayDiff:(SPArrayDiff *)arrayDiff error:(NSError *__autoreleasing *)error;

- (SPArrayDiff *)sp_arrayDiffByTransformingArrayDiff:(SPArrayDiff *)arrayDiff1 ontoArrayDiff:(SPArrayDiff *)arrayDiff2 policy:(SPDiffPolicy *)diffPolicy error:(NSError *__autoreleasing *)error;

@end

typedef NSDictionary SPObjectDiff;

@interface NSDictionary (SPJSONDiff)

- (SPObjectDiff *)sp_objectDiffToTargetObject:(NSDictionary *)targetObject policy:(SPDiffPolicy *)policy;
- (NSDictionary *)sp_objectByApplyingObjectDiff:(SPObjectDiff *)diff error:(NSError *__autoreleasing *)error;
- (NSDictionary *)sp_objectDiffByTransformingObjectDiff:(SPObjectDiff *)objectDiff1 ontoObjectDiff:(SPObjectDiff *)objectDiff2 policy:(SPDiffPolicy *)diffPolicy error:(NSError *__autoreleasing *)error;

@end

