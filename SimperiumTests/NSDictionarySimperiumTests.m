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
    NSString *invalid = [NSString stringWithFormat:@"%C%C%C%C%C%C%C%C%C%C%C%C", 0x263a, 0xfe0f, 0xd83d, 0x28, 0x6e, 0x75, 0x6c, 0x6c, 0x29, 0xdd96, 0xd83c, 0xdfff];
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

- (void)testStringContainingAllPossibleUnicodeCharactersDoesNotCauseInvalidJsonFlag {

    NSMutableString *sample = [[NSMutableString alloc] initWithCapacity:USHRT_MAX];
    unichar const surrogateLowest = 0xDC00UL;
    unichar const surrogateHighest = 0xDFFFUL;
    NSInteger index = -1;

    while (++index != USHRT_MAX) {
        unichar character = (unichar)index;

        // Lower Surrogate: Skip
        if (CFStringIsSurrogateLowCharacter(character)) {
            continue;
        }

        // Regular Character
        if (CFStringIsSurrogateHighCharacter(character) == false) {
            [sample appendFormat:@"%C", character];
            continue;
        }

        // Higher Surrogate: Build *every* High / Lower possible combination
        unichar pair = surrogateLowest;

        while (pair != surrogateHighest) {
            [sample appendFormat:@"%C%C", character, pair];
            pair += 1;
        }
    }

    NSDictionary *validObject = @{
        NSStringFromClass([self class]): sample,
    };

    XCTAssertTrue([validObject sp_isValidJsonObject], @"Dictionary is expected to be a valid json");
}

@end
