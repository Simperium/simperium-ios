//
//  NSDictionarySimperiumTests.m
//  UnitTests
//
//  Created by Jorge Leandro Perez on 12/17/19.
//  Copyright © 2019 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "JSONKit+Simperium.h"

@interface NSDictionarySimperiumTests : XCTestCase

@end

@implementation NSDictionarySimperiumTests

- (void)testStringsContainingBrokenSurrogatePairsAreDetectedAsInvalidObject {
    NSString *invalid = [NSString stringWithFormat:@"%C%C%C%C%C%C%C%C%C%C%C%C", 9786, 65039, 55357, 40, 110, 117, 108, 108, 41, 56726, 55356, 57343];
    NSDictionary *invalidObject = @{
        @"content": invalid,
    };

    XCTAssertFalse([invalidObject sp_isValidJsonObject], @"Dictionary is expected not to be a valid json");
}

- (void)testWellFormedStringsArentDetectedAsInvalidObjects {
    NSDictionary *invalidObject = @{
        @"content": @{
            @"UUID": [[NSUUID new] UUIDString]
        }
    };

    XCTAssertTrue([invalidObject sp_isValidJsonObject], @"Dictionary is expected to be a valid json");
}

@end
