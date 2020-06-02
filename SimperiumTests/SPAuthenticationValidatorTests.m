#import <XCTest/XCTest.h>
#import "XCTestCase+Simperium.h"
#import "SPAuthenticationValidator.h"

@interface SPAuthenticationValidatorTests : XCTestCase
@property (nonatomic, strong) SPAuthenticationValidator *validator;
@end

@implementation SPAuthenticationValidatorTests

- (void)setUp {
    self.validator = [SPAuthenticationValidator new];
}

- (void)testPerformUsernameValidationReturnsTrueWheneverInputEmailIsValid {
    NSArray *emails = @[
        @"j@j.com",
        @"something@simplenote.blog",
        @"something@simplenote.blog.ar"
    ];

    for (NSString *email in emails) {
        NSError *error = nil;
        BOOL isValid = [self.validator validateUsername:email error:&error];

        XCTAssertTrue(isValid);
        XCTAssertNil(error);
    }
}

- (void)testValidateUsernameReturnsErrorWheneverInputStringIsShorterThanExpected {
    NSString *username = @"somethinghere";
    NSError *error = nil;
    BOOL isValid = [self.validator validateUsername:username error:&error];

    XCTAssertFalse(isValid);
    XCTAssertEqual(error.code, SPAuthenticationErrorsEmailInvalid);
}

- (void)testValidatePasswordReturnsErrorWheneverPasswordMatchesUsername {
    NSString *username = @"somethinghere";
    NSError *error = nil;
    BOOL isValid = [self.validator validatePasswordWithUsername:username password:username error:&error];

    XCTAssertFalse(isValid);
    XCTAssertEqual(error.code, SPAuthenticationErrorsPasswordMatchesUsername);
}

- (void)testValidatePasswordReturnsErrorWheneverPasswordContainsInvalidCharacters {
    NSString *username = @"somethinghere";
    NSArray *passwords = @[
        @"\t12345678",
        @"\n12345678",
        @"1234\n5678\t",
        @"12345678\t"
    ];

    for (NSString *password in passwords) {
        NSError *error = nil;
        BOOL isValid = [self.validator validatePasswordWithUsername:username password:password error:&error];

        XCTAssertFalse(isValid);
        XCTAssertEqual(error.code, SPAuthenticationErrorsPasswordContainsInvalidCharacter);
    }
}

- (void)testMustPerformPasswordResetReturnsTrueWheneverPasswordIsConsideredInsecure {
    NSString *username = @"something@here.com";
    NSArray *passwords = @[
        username,
        @"1234",
        @"12345",
        @"123456",
    ];

    for (NSString *password in passwords) {
        XCTAssertTrue([self.validator mustPerformPasswordResetWithUsername:username password:password]);
    }
}

- (void)testMustPerformPasswordResetReturnsFalseWheneverPasswordIsSecure {
    NSString *username = @"something@here.com";
    NSString *password = @"12345678";

    XCTAssertFalse([self.validator mustPerformPasswordResetWithUsername:username password:password]);
}

@end
