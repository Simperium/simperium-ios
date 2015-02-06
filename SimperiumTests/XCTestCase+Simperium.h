//
//  XCTestCase+Simperium.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 11/12/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface XCTestCase (Simperium)
- (void)waitFor:(NSTimeInterval)seconds;
- (void)assertNoThrow:(void (^)())block;
@end
