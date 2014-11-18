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

- (instancetype)init {
    if (self = [super init]) {
        _objectsShouldSync = true;
    }
    return self;
}

- (void)storage:(SPStorage *)storage updatedObjects:(NSSet *)updatedObjects insertedObjects:(NSSet *)insertedObjects deletedObjects:(NSSet *)deletedObjects
{
    if (self.callback) {
        self.callback(insertedObjects, updatedObjects, deletedObjects);
    }
}

@end
