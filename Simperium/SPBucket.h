//
//  SPBucket.h
//  Simperium
//
//  Created by Michael Johnston on 12-04-12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPStorageProvider.h"
#import "SPNetworkProvider.h"

@class SPDiffer;
@class SPSchema;
@class SPStorage;
@class SPBucket;
@class SPChangeProcessor;
@class SPIndexProcessor;
@class SPReferenceManager;

/** SPBucketChangeType is used in the bucket:didChangeObjectForKey:forChangeType: method of SPBucketDelegate. It's similar to NSFetchedResultsChangeType, which is used with an NSFetchedResultsControllerDelegate.
 */
enum {
	SPBucketChangeInsert = 1,
    SPBucketChangeDelete = 2,
	SPBucketChangeMove = 3, // not yet implemented
	SPBucketChangeUpdate = 4,
    SPBucketChangeAcknowledge = 5
};
typedef NSUInteger SPBucketChangeType;


/** Delegate protocol for Simperium bucket notifications.
 
 You can use this delegate to respond to object changes and errors that happen as a result of data moving over the network.
 */
@protocol SPBucketDelegate <NSObject>
@optional
-(void)bucket:(SPBucket *)bucket didChangeObjectForKey:(NSString *)key forChangeType:(SPBucketChangeType)changeType;
-(void)bucket:(SPBucket *)bucket willChangeObjectsForKeys:(NSSet *)keys;
-(void)bucketWillStartIndexing:(SPBucket *)bucket;
-(void)bucketDidFinishIndexing:(SPBucket *)bucket;
-(void)bucket:(SPBucket *)bucket didReceiveObjectForKey:(NSString *)key version:(NSString *)version data:(NSDictionary *)data;
-(void)bucketDidAcknowledgeDelete:(SPBucket *)bucket;
-(void)bucket:(SPBucket *)bucket didFailWithError:(NSError *)error;
-(void)bucket:(SPBucket *)bucket didShareObjectForKey:(NSString *)key withEmail:(NSString *)email;
@end

/** An SPBucket instance is conceptually a collection of all objects of a particular type. If you're using Core Data, there is one SPBucket per Entity in your model, and it's used to track all objects corresponding to that Entity type.
 */
@interface SPBucket : NSObject {
    NSString *name;
    NSString *instanceLabel;
    id<SPNetworkProvider> network;
    SPReferenceManager *referenceManager;
    SPDiffer *differ;
    id<SPStorageProvider> storage;
    SPSchema *schema;
    dispatch_queue_t processorQueue;
    
    id<SPBucketDelegate> delegate;
    
    NSString *lastChangeSignature;
}

/// Assign this delegate to be notified when objects in this bucket change (see SPBucketDelegate above)
@property (assign) id<SPBucketDelegate> delegate;
@property (nonatomic, readonly) NSString *name;


/** The following are convenience methods for accessing, inserting and deleting objects. If you're using Core Data, you can instead just access your context directly and Simperium will identify any changes accordingly.
 */

// Retrieve an object that has a particular simperiumKey
-(id)objectForKey:(NSString *)key;

// Retrieve all objects in the bucket
-(NSArray *)allObjects;

// Insert a new object in the bucket (and optionally specify a particular simperiumKey)
-(id)insertNewObject;
-(id)insertNewObjectForKey:(NSString *)simperiumKey;

// Retrieve objects for a particular set of keys
-(NSArray *)objectsForKeys:(NSSet *)keys;

// Delete a particular object
-(void)deleteObject:(id)object;

// Delete all objects in the bucket
-(void)deleteAllObjects;

// Efficiently returns the number of objects in the bucket (optionally specifying a predicate).
-(NSInteger)numObjects;
-(NSInteger)numObjectsForPredicate:(NSPredicate *)predicate;


/** For internal use
 */
@property (nonatomic, copy) NSString *instanceLabel;
@property (nonatomic, retain) id<SPStorageProvider> storage;
@property (nonatomic, retain) id<SPNetworkProvider> network;
@property (nonatomic, retain) SPDiffer *differ;
@property (nonatomic, retain) SPReferenceManager *referenceManager;
@property (retain) SPChangeProcessor* changeProcessor;
@property (retain) SPIndexProcessor* indexProcessor;
@property (assign) dispatch_queue_t processorQueue;
@property (nonatomic, copy) NSString *lastChangeSignature;

-(id)initWithSchema:(SPSchema *)aSchema storage:(id<SPStorageProvider>)aStorage networkProvider:(id<SPNetworkProvider>)netProvider referenceManager:(SPReferenceManager *)refManager label:(NSString *)label;
-(void)validateObjects;
-(void)unloadAllObjects;

@end
