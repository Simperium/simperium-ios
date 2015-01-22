//
//  MockStorage.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 4/17/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "MockStorage.h"
#import "SPObject.h"
#import "NSString+Simperium.h"
#import "NSConditionLock+Simperium.h"



static NSInteger const SPWorkersDone = 0;


@interface MockStorage ()
@property (nonatomic, strong) NSMutableDictionary   *storage;
@property (nonatomic, strong) NSConditionLock       *mutex;
@end


@implementation MockStorage

@synthesize metadata = _metadata;

- (instancetype)init {
    if ((self = [super init])) {
        _storage    = [NSMutableDictionary dictionary];
        _metadata   = [NSMutableDictionary dictionary];
		_mutex      = [[NSConditionLock alloc] initWithCondition:SPWorkersDone];
    }
    return self;
}

- (BOOL)save {
    // No-Op
    return YES;
}

- (NSArray *)objectsForBucketName:(NSString *)bucketName predicate:(NSPredicate *)predicate {
    NSArray *objects = [self.storage[bucketName] allValues];
    return [objects filteredArrayUsingPredicate:predicate];
}

- (NSArray *)objectKeysForBucketName:(NSString *)bucketName {
    return [self.storage[bucketName] allKeys];
}

- (id)objectForKey:(NSString *)key bucketName:(NSString *)bucketName {
    return self.storage[bucketName][key];
}

- (NSArray *)objectsForKeys:(NSSet *)keys bucketName:(NSString *)bucketName {
    NSMutableArray *array = [NSMutableArray array];
    
    for (NSString *key in keys) {
        id object = [self objectForKey:key bucketName:bucketName];
        if (object) {
            [array addObject:object];
        }
    }
    
    return array;
}

- (id)objectAtIndex:(NSUInteger)index bucketName:(NSString *)bucketName {
    // Not supported
    return nil;
}

- (NSInteger)numObjectsForBucketName:(NSString *)bucketName predicate:(NSPredicate *)predicate {
    NSArray *objects = [self.storage[bucketName] allValues];
    if (predicate) {
        return [[objects filteredArrayUsingPredicate:predicate] count];
    } else {
        return objects.count;
    }
}

- (NSDictionary *)faultObjectsForKeys:(NSArray *)keys bucketName:(NSString *)bucketName {
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    
    for (NSString *key in keys) {
        id object = [self objectForKey:key bucketName:bucketName];
        if (object) {
            dictionary[key] = object;
        }
    }
    
    return dictionary;
}

- (void)refaultObjects:(NSArray *)objects {
    // No-Op
}

- (void)insertObject:(id)object bucketName:(NSString *)bucketName {
    if ([object isKindOfClass:[SPObject class]] == NO) {
        return;
    }
    
    // Load the bucket
    NSMutableDictionary *bucket = self.storage[bucketName];
    if (!bucket) {
        // Old School double check after lock, to improve performance
        @synchronized(self) {
            bucket = self.storage[bucketName];
            if (!bucket) {
                bucket = [NSMutableDictionary dictionary];
                self.storage[bucketName] = bucket;
            }
        }
    }
    
    // Insert
    SPObject *theObject = (SPObject *)object;
    bucket[theObject.simperiumKey] = object;

}

- (id)insertNewObjectForBucketName:(NSString *)bucketName simperiumKey:(NSString *)key {
    // Not supported
    return nil;
}

- (void)deleteObject:(id)object {
    SPObject *theObject = (SPObject *)object;
    if ([theObject isKindOfClass:[SPObject class]]) {
        [self stopManagingObjectWithKey:theObject.simperiumKey];
    }
}

- (void)deleteAllObjectsForBucketName:(NSString *)bucketName {
    [self.storage removeObjectForKey:bucketName];
}

- (void)validateObjectsForBucketName:(NSString *)bucketName {
    // No-Op
}

- (void)stopManagingObjectWithKey:(NSString *)key {
    for (NSMutableDictionary *bucket in self.storage.allValues) {
        [bucket removeObjectForKey:key];
    }
}

- (id<SPStorageProvider>)threadSafeStorage {
    return self;
}

- (void)stashUnsavedObjects {
    // No-Op
}

- (NSSet *)stashedObjects {
    // No-Op
    return nil;
}

- (NSSet *)deletedObjects {
    // No-Op
    return nil;
}
- (NSSet *)insertedObjects {
    // No-Op
    return nil;
}
- (NSSet *)updatedObjects {
    // No-Op
    return nil;
}

- (void)unstashUnsavedObjects {
    // No-Op
}

- (void)unloadAllObjects {
    // No-Op
}

- (void)commitPendingOperations:(void (^)())completion {
    completion();
}


#pragma mark - Synchronization

- (void)performSafeBlockAndWait:(void (^)())block {
	NSAssert([NSThread isMainThread] == false, @"It is not recommended to use this method on the main thread");
    
    [self.mutex sp_increaseCondition];
    block();
    [self.mutex sp_decreaseCondition];
}

- (void)performCriticalBlockAndWait:(void (^)())block {
	NSAssert([NSThread isMainThread] == false, @"It is not recommended to use this method on the main thread");

    [self.mutex lockWhenCondition:SPWorkersDone];
    block();
	[self.mutex unlock];
}

@end
