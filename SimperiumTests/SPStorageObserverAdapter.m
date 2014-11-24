//
//  SPStorageObserverAdapter.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 11/18/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "SPStorageObserverAdapter.h"
#import "SPStorage.h"

@implementation SPStorageObserverAdapter

- (void)storageWillSave:(id<SPStorageProvider>)storage deletedObjects:(NSSet *)deletedObjects
{
    if (self.willSaveCallback) {
        self.willSaveCallback(deletedObjects);
    }
    
}

- (void)storageDidSave:(id<SPStorageProvider>)storage insertedObjects:(NSSet *)insertedObjects updatedObjects:(NSSet *)updatedObjects
{
    if (self.didSaveCallback) {
        self.didSaveCallback(insertedObjects, updatedObjects);
    }
}

@end
