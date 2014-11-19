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

- (void)storageWillSave:(id<SPStorageProvider>)storage
{
    if (self.willSaveCallback) {
        self.willSaveCallback(storage.insertedObjects, storage.updatedObjects, storage.deletedObjects);
    }
    
}

- (void)storageDidSave:(id<SPStorageProvider>)storage
{
    if (self.didSaveCallback) {
        self.didSaveCallback(storage.insertedObjects, storage.updatedObjects, storage.deletedObjects);
    }
}

@end
