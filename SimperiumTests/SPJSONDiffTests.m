//
//  DiffMatchPatchArrayTests.m
//  Simperium
//
//  Created by Andrew Mackenzie-Ross on 19/07/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPJSONDiffTests.h"
#import "SPJSONDiff.h"
#import "SPMember.h"



@implementation SPJSONDiffTests

- (void)testArrayDMPDiffs
{
	NSDictionary *testsOneElementOperationPairs = @{
							  @[ @"a" ]: @[  @1 ] , // replace one element
		 @[ @"a" ]: @[], // remove element
		 @[]: @[ @"a" ], // add element to empty array
		 @[ @"a" ]: @[ @"a", @1 ], // add element to existing
		 @[ @"a", @1 ]: @[ @"a" ], // remove last element
		 @[ @"a", @1 ]: @[ @1 ], // remove first element
		 };
	NSDictionary *testTwoElementOperationsPairs = @{
		 @[ @"a", @1 ]: @[ @YES, @1 ], // replace first element
   @[ @"a", @1 ]: @[ @"a" , @2 ], // replace last element
   @[ @"a", @1 ]: @[ @1, @"a" ], // inverse two elements
   @[ @"a", @1 ]: @[ @"b", @2 ], // two new elements
   @[ @"a", @1 ]: @[ @"b", @"a", @1 ], // insert new element at head
   @[ @"b", @"a", @1 ]: @[ @"a", @1 ], // remove element from head
   @[ @"a", @1 ]: @[ @"a", @"b", @1 ], // insert element in midde
   @[ @"a", @"b", @1 ]: @[ @"a", @1 ], // remove element from middle
   @[ @"a", @1 ]: @[ @"a", @1, @"b" ], // insert element at tail
   @[ @"a", @1, @"b" ]: @[ @"a", @1 ], // remove element from tail
   @[] : @[ @"a", @1 ], // insert two elements
   @[ @"a", @1 ]: @[] // remove two elements
   };
	
	NSDictionary *testThreeElementOperationsPairs = @{
												 @[ @"a", @1 ]: @[ @YES, @1 ], // replace first element
			 @[ @"a", @1, [NSNull null] ]: @[ @"a" , @2, @[ @YES, @"NO", @{ @"something" : @"with objects" } ] ], // replace last element
			 @[ @"a", @1, [NSNull null] ]: @[ @1, @"a", [NSNull null] ], // inverse two elements
			 };
	
	[testsOneElementOperationPairs enumerateKeysAndObjectsUsingBlock:^(id array1, id array2, BOOL *stop) {
		STAssertEqualObjects(array1, [self createDMPDiffAndApplyDMPDiffArray1:array2 array2:array1], @"replace diff 1 element");
	}];
	[testTwoElementOperationsPairs enumerateKeysAndObjectsUsingBlock:^(id array1, id array2, BOOL *stop) {
		STAssertEqualObjects(array1, [self createDMPDiffAndApplyDMPDiffArray1:array2 array2:array1], @"replace diff 1 element");
	}];
	
	[testThreeElementOperationsPairs enumerateKeysAndObjectsUsingBlock:^(id array1, id array2, BOOL *stop) {
		STAssertEqualObjects(array1, [self createDMPDiffAndApplyDMPDiffArray1:array2 array2:array1], @"replace diff 1 element");
	}];
}

- (NSArray *)createDMPDiffAndApplyDMPDiffArray1:(NSArray *)array1 array2:(NSArray *)array2
{
	NSString *diff = [array1 sp_arrayDMPDiffToTargetArray:array2 policy:nil];
	return [array1 sp_arrayByApplyingArrayDMPDiff:diff];
}

- (void)testStringDiffs
{
    NSDictionary *testDiffs = @{ @"": @"a",
                                  @"b": @"a",
                                  @"a": @"",
                                  @"abc":@"cba",
                                  @"ab": @"c",
                                  @"ca": @"",
                                  @"cab": @"xyb",
                                  @"af": @"af"};
    for (NSString *v1 in testDiffs) {
        NSString *v2 = testDiffs[v1];
        NSString *diff = [v1 sp_stringDiffToTargetString:v2];
        NSString *result = [v1 sp_stringByApplyingStringDiff:diff];
        STAssertEqualObjects(v2, result, @"string diff diff");
    }
    
    NSString *diff1 = [@"a" sp_stringDiffToTargetString:@"a book"];
    NSString *diff2 = [@"a" sp_stringDiffToTargetString:@"he has a"];
    NSString *transformedDiff = [@"a" sp_stringDiffByTransformingStringDiff:diff1 ontoStringDiff:diff2];
    NSString *afterApplyingDiff2 = [@"a" sp_stringByApplyingStringDiff:diff2];
    STAssertEqualObjects([afterApplyingDiff2 sp_stringByApplyingStringDiff:transformedDiff], @"he has a book", @"transforms");
}

- (void)testIntegerDiffs
{
    NSDictionary *testDiffs = @{ @1: @2,
                                  @5: @5,
                                  @0: @(-4) };
    for (NSNumber *v1 in testDiffs) {
        NSNumber *v2 = testDiffs[v1];
        NSNumber *diff = [v1 sp_numberDiffToTargetNumber:v2];
        NSNumber *result = [v1 sp_numberByApplyingNumberDiff:diff];
        STAssertEqualObjects(v2, result, @"number diff diff");
    }
    
    NSNumber * original = @5;
    NSNumber * target = @6;
    NSNumber * target2 = @6;
    NSNumber *diff1 = [original sp_numberDiffToTargetNumber:target];
    NSNumber *diff2 = [original sp_numberDiffToTargetNumber:target2];
    NSNumber *transformedDiff = [original sp_numberDiffByTransformingNumberDiff:diff1 ontoNumberDiff:diff2];
    
    NSNumber *resultAfterDiff2 = [original sp_numberByApplyingNumberDiff:diff2];
    NSNumber *result = [resultAfterDiff2 sp_numberByApplyingNumberDiff:transformedDiff];
    STAssertEqualObjects(@7, result, @"number diff diff");
}

- (void)testFullArrayDiff
{
    NSDictionary *testsOneElementOperationPairs = @{
                                                    @[ @"a" ]: @[  @1 ] , // replace one element
                                                    @[ @"a" ]: @[], // remove element
                                                    @[]: @[ @"a" ], // add element to empty array
                                                    @[ @"a" ]: @[ @"a", @1 ], // add element to existing
                                                    @[ @"a", @1 ]: @[ @"a" ], // remove last element
                                                    @[ @"a", @1 ]: @[ @1 ], // remove first element
                                                    };
	NSDictionary *testTwoElementOperationsPairs = @{
                                                 @[ @"a", @1 ]: @[ @YES, @1 ], // replace first element
                                                 @[ @"a", @1 ]: @[ @"a" , @2 ], // replace last element
                                                 @[ @"a", @1 ]: @[ @1, @"a" ], // inverse two elements
                                                 @[ @"a", @1 ]: @[ @"b", @2 ], // two new elements
                                                 @[ @"a", @1 ]: @[ @"b", @"a", @1 ], // insert new element at head
                                                 @[ @"b", @"a", @1 ]: @[ @"a", @1 ], // remove element from head
                                                 @[ @"a", @1 ]: @[ @"a", @"b", @1 ], // insert element in midde
                                                 @[ @"a", @"b", @1 ]: @[ @"a", @1 ], // remove element from middle
                                                 @[ @"a", @1 ]: @[ @"a", @1, @"b" ], // insert element at tail
                                                 @[ @"a", @1, @"b" ]: @[ @"a", @1 ], // remove element from tail
                                                 @[] : @[ @"a", @1 ], // insert two elements
                                                 @[ @"a", @1 ]: @[] // remove two elements
                                                 };
	
	NSDictionary *testThreeElementOperationsPairs = @{
                                                   @[ @"a", @1 ]: @[ @YES, @1 ], // replace first element
                                                   @[ @"a", @1, [NSNull null] ]: @[ @"a" , @2, @[ @YES, @"NO", @{ @"something" : @"with objects" } ] ], // replace last element
                                                   @[ @"a", @1, [NSNull null] ]: @[ @1, @"a", [NSNull null] ], // inverse two elements
                                                   @[ @"o", @"x", @"o", @"o" ]: @[ @"o", @"x", @"o", @"o",@"x", @"o", @"o" ], // tricky ones
                                                   @[ @"o", @"x", @"o", @"o", @"x", @"o" ]: @[ @"o", @"x", @"o" ],
                                                   @[ @"o", @"x", @"o",@"x", @"o", @"x", @"o" ]: @[ @"o", @"x", @"o" ],

                                                   };

	
	[testsOneElementOperationPairs enumerateKeysAndObjectsUsingBlock:^(id array1, id array2, BOOL *stop) {
		STAssertEqualObjects(array1, [self createDiffAndApplyDiffArray1:array2 array2:array1], @"replace diff 1 element");
	}];
	[testTwoElementOperationsPairs enumerateKeysAndObjectsUsingBlock:^(id array1, id array2, BOOL *stop) {
		STAssertEqualObjects(array1, [self createDiffAndApplyDiffArray1:array2 array2:array1], @"replace diff 1 element");
	}];
	
	[testThreeElementOperationsPairs enumerateKeysAndObjectsUsingBlock:^(id array1, id array2, BOOL *stop) {
		STAssertEqualObjects(array1, [self createDiffAndApplyDiffArray1:array2 array2:array1], @"replace diff 1 element");
	}];
}

- (NSArray *)createDiffAndApplyDiffArray1:(NSArray *)array1 array2:(NSArray *)array2
{
	NSDictionary *diff = [array1 sp_arrayDiffToTargetArray:array2 policy:nil];
	return [array1 sp_arrayByApplyingArrayDiff:diff];
}

- (void)testArrayDMPDiffTransforms
{
    NSArray *sourceArrays = @[ @[ @[ @"a" ], @[ @"b", @"c"] ] ];
    NSArray *diff1Arrays = @[ @[ @[ @"a", @"3" ], @[ @"b", @"f"] ] ];
    NSArray *diff2Arrays = @[ @[ @[ ], @[ @"o", @"c"] ] ];
    NSArray *resultArrays = @[ @[ @[ @"a", @"3" ], @[ @"b", @"f"] ] ];
    int i = 0;
    for (NSArray *source in sourceArrays) {
        
        SPArrayDMPDiff *diff1 = [source sp_arrayDMPDiffToTargetArray:diff1Arrays[i] policy:@{ @"item": @{ @"attributes": @{ @"otype": @"dL" } }}];
        SPArrayDMPDiff *diff2 = [source sp_arrayDMPDiffToTargetArray:diff2Arrays[i] policy:@{ @"item": @{ @"attributes": @{ @"otype": @"dL" } }}];
        NSArray *resultOfDiff2 = [source sp_arrayByApplyingArrayDMPDiff:diff2];
        STAssertEqualObjects(resultOfDiff2, diff2Arrays[i], @"Applying diff 2 should work");
        SPArrayDMPDiff *transformedDiff = [source sp_arrayDMPDiffByTransformingArrayDMPDiff:diff1 ontoArrayDMPDiff:diff2 policy:@{ @"item": @{ @"attributes": @{ @"otype": @"dL" } }}];
        NSArray *result = [resultOfDiff2 sp_arrayByApplyingArrayDMPDiff:transformedDiff];
        STAssertEqualObjects(result, resultArrays[i], @"The final array should equal the correct result");
        i++;
    }

    
}



@end
