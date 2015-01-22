//
//  NSConditionLock+Simperium.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 1/22/15.
//  Copyright (c) 2015 Simperium. All rights reserved.
//

#import <Simperium/Simperium.h>


@interface NSConditionLock (Simperium)

- (void)sp_increaseCondition;
- (void)sp_decreaseCondition;

@end
