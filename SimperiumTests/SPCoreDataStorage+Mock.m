//
//  SPCoreDataStorage+Mock.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 12/2/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "SPCoreDataStorage+Mock.h"



@implementation SPCoreDataStorage (Mock)

- (void)test_waitUntilSaveCompletes
{
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_enter(group);

    [self commitPendingOperations:^{
        dispatch_group_leave(group);
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

@end
