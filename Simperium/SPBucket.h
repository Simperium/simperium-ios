//
//  SPBucket.h
//  Simperium
//
//  Created by Michael Johnston on 12-04-12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPStorageProvider.h"
#import "SPNetworkInterface.h"

@class SPDiffer;
@class SPSchema;
@class SPStorage;
@class SPBucket;
@class SPChangeProcessor;
@class SPIndexProcessor;
@class SPRelationshipResolver;

/** SPBucketChangeType is used in the bucket:didChangeObjectForKey:forChangeType: method of SPBucketDelegate. It's similar to NSFetchedResultsChangeType, which is used with an NSFetchedResultsControllerDelegate.
 */
typedef NS_ENUM(NSUInteger, SPBucketChangeType) {
    SPBucketChangeTypeInsert        = 1,
    SPBucketChangeTypeDelete        = 2,
    SPBucketChangeTypeMove          = 3, // not yet implemented
    SPBucketChangeTypeUpdate        = 4,
    SPBucketChangeTypeAcknowledge   = 5
};


/** Delegate protocol for Simperium bucket notifications.
 
 You can use this delegate to respond to object changes and errors that happen as a result of data moving over the network. Note
 that these are currently NOT fired during indexing (i.e. on a clean install when there is data already stored in Simperium).
 */
@protocol SPBucketDelegate <NSObject>
@optional
- (void)bucket:(SPBucket *)bucket didChangeObjectForKey:(NSString *)key forChangeType:(SPBucketChangeType)changeType memberNames:(NSArray *)memberNames;
- (void)bucket:(SPBucket *)bucket willChangeObjectsForKeys:(NSSet *)keys;
- (void)bucketWillStartIndexing:(SPBucket *)bucket;
- (void)bucketDidFinishIndexing:(SPBucket *)bucket;
- (void)bucket:(SPBucket *)bucket didReceiveObjectForKey:(NSString *)key version:(NSString *)version data:(NSDictionary *)data;
- (void)bucketDidAcknowledgeDelete:(SPBucket *)bucket;
- (void)bucket:(SPBucket *)bucket didFailWithError:(NSError *)error;
- (void)bucket:(SPBucket *)bucket didShareObjectForKey:(NSString *)key withEmail:(NSString *)email;
@end

/** An SPBucket instance is conceptually a collection of all objects of a particular type. If you're using Core Data, there is one SPBucket per Entity in your model, and it's used to track all objects corresponding to that Entity type.
 */
@interface SPBucket : NSObject

@property (nonatomic, copy, readonly) NSString *name;

@property (nonatomic, copy, readonly) NSString *remoteName;

// Assign this delegate to be notified when objects in this bucket change (see SPBucketDelegate above)
@property (nonatomic, weak) id<SPBucketDelegate> delegate;

// Enable this to receive SPBucketDelegate notifications during indexing (disabled by default because it's slow)
@property (nonatomic, assign) BOOL notifyWhileIndexing;

// When enabled, Simperium will catch any exceptions thrown while setting property values, and log the error.
// This may prove useful to prevent data type mismatch crashes.
@property (nonatomic, assign) BOOL propertyMismatchFailsafeEnabled;


/** The following are convenience methods for accessing, inserting and deleting objects. If you're using Core Data, you can instead just access your context directly and Simperium will identify any changes accordingly.
 */

// Retrieve an object that has a particular simperiumKey
- (id)objectForKey:(NSString *)simperiumKey;

// Retrieve all objects in the bucket
- (NSArray *)allObjects;

// Insert a new object in the bucket (and optionally specify a particular simperiumKey)
- (id)insertNewObject;
- (id)insertNewObjectForKey:(NSString *)simperiumKey;

// Retrieve objects for a particular set of keys
- (NSArray *)objectsForKeys:(NSSet *)keys;

// Retrieve objects filtered by a predicate
- (NSArray *)objectsForPredicate:(NSPredicate *)predicate;

// Retrieve a certain number of past versions for a particular object key
// (will result in didReceiveObjectForKey:version:data: getting fired)
- (void)requestVersions:(int)numVersions key:(NSString *)simperiumKey;

// Delete a particular object
- (void)deleteObject:(id)object;

// Delete all objects in the bucket
- (void)deleteAllObjects;

// Efficiently returns the number of objects in the bucket (optionally specifying a predicate).
- (NSInteger)numObjects;
- (NSInteger)numObjectsForPredicate:(NSPredicate *)predicate;

// Retrive Simperium's Sync'ing stats:
//  - Local Pending Changes:    Number of captured changes, pending to be sent / acknowledged
//  - Local Enqueued Changes:   Number of objects marked for further processing
//  - Local Enqueued Deletions: Number of objects marked for deletion
typedef void(^SPBucketStatsCallback)(SPBucket *bucket, NSUInteger localPendingChanges, NSUInteger localEnqueuedChanges, NSUInteger localEnqueuedDeletions);
- (void)statsWithCallback:(SPBucketStatsCallback)callback;

@end
