//
//  SPStorageProvider.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-17.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPDiffable.h"



#pragma mark ====================================================================================
#pragma mark SPStorageProvider
#pragma mark ====================================================================================

@protocol SPStorageProvider <NSObject>

// Properties
@property (nonatomic, copy, readwrite) NSDictionary *metadata;
@property (nonatomic, copy,  readonly) NSSet        *stashedObjects;

// Persistance
- (BOOL)save;
- (void)commitPendingOperations:(void (^)())completion;

// Helpers
- (NSArray *)objectsForBucketName:(NSString *)bucketName predicate:(NSPredicate *)predicate;
- (NSArray *)objectKeysForBucketName:(NSString *)bucketName;
- (id)objectForKey:(NSString *)key bucketName:(NSString *)bucketName;
- (NSArray *)objectsForKeys:(NSSet *)keys bucketName:(NSString *)bucketName;
- (id)objectAtIndex:(NSUInteger)index bucketName:(NSString *)bucketName;
- (NSInteger)numObjectsForBucketName:(NSString *)bucketName predicate:(NSPredicate *)predicate;
- (NSDictionary *)faultObjectsForKeys:(NSArray *)keys bucketName:(NSString *)bucketName;
- (void)refaultObjects:(NSArray *)objects;
- (void)insertObject:(id)object bucketName:(NSString *)bucketName;
- (id)insertNewObjectForBucketName:(NSString *)bucketName simperiumKey:(NSString *)key;
- (void)deleteObject:(id)object;
- (void)deleteAllObjectsForBucketName:(NSString *)bucketName;
- (void)validateObjectsForBucketName:(NSString *)bucketName;
- (void)stopManagingObjectWithKey:(NSString *)key;

// Stashing
- (void)stashUnsavedObjects;
- (void)unstashUnsavedObjects;
- (void)unloadAllObjects;

// Synchronization
- (id<SPStorageProvider>)threadSafeStorage;
- (void)beginSafeSection;
- (void)finishSafeSection;
- (void)performCriticalBlockAndWait:(void (^)())block;

@optional
- (void)object:(id)object forKey:(NSString *)simperiumKey didChangeValue:(id)value forKey:(NSString *)key;

@end
