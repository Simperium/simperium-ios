//
//  NSConditionLock+Simperium.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 1/22/15.
//  Copyright (c) 2015 Simperium. All rights reserved.
//

#import "NSConditionLock+Simperium.h"


@implementation NSConditionLock (Simperium)

- (void)sp_increaseCondition {
    [self lock];
    NSInteger condition = self.condition + 1;
    [self unlockWithCondition:condition];
}

- (void)sp_decreaseCondition {
    [self lock];
    NSInteger condition = self.condition - 1;
    [self unlockWithCondition:condition];
}

@end
