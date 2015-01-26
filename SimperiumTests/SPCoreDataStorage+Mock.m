//
//  SPCoreDataStorage+Mock.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 12/2/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "SPCoreDataStorage+Mock.h"
#import <CoreData/CoreData.h>
#import "jrswizzle.h"



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

+ (void)initialize
{
    [SPCoreDataStorage jr_swizzleMethod:@selector(childrenContextWillSave:)
                             withMethod:@selector(test_childrenContextWillSave:)
                                  error:nil];
}

- (void)test_childrenContextWillSave:(NSNotification *)note
{
    // ThreadsafeStorage Instances don't normally need delegate calls. This is done just for Unit Testing Purposes
    [self performSelector:@selector(test_childrenContextWillSave:) withObject:note];
    [self.delegate storageWillSave:self deletedObjects:self.mainManagedObjectContext.deletedObjects];
}

@end
