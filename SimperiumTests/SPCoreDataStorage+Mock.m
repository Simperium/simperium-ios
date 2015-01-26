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



@interface SPCoreDataStorage ()
- (void)childrenContextDidSave:(NSNotification *)note;
@end



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

- (void)test_simulateWorkerOnlyMergesChangesIntoWriter
{
    [SPCoreDataStorage jr_swizzleMethod:@selector(childrenContextDidSave:)
                             withMethod:@selector(test_childrenContextDidSaveMergesOnlyWriterContext:)
                                  error:nil];
}

- (void)test_simulateWorkerCannotMergeChangesAnywhere
{
    [SPCoreDataStorage jr_swizzleMethod:@selector(childrenContextDidSave:)
                             withMethod:@selector(test_childrenContextDidSaveCannotMergeChanges:)
                                  error:nil];
}

- (void)test_childrenContextDidSaveMergesOnlyWriterContext:(NSNotification *)note {

    NSManagedObjectContext *writerMOC = self.writerManagedObjectContext;
    [writerMOC performBlockAndWait:^{
        [writerMOC mergeChangesFromContextDidSaveNotification:note];
    }];
    
    [self.delegate storageDidSave:self
                  insertedObjects:self.mainManagedObjectContext.insertedObjects
                   updatedObjects:self.mainManagedObjectContext.updatedObjects];
}

- (void)test_childrenContextDidSaveCannotMergeChanges:(NSNotification *)note {
    
    [self.delegate storageDidSave:self
                  insertedObjects:self.mainManagedObjectContext.insertedObjects
                   updatedObjects:self.mainManagedObjectContext.updatedObjects];
}

@end
