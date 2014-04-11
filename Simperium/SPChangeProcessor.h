//
//  SPChangeProcessor.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-15.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPProcessorNotificationNames.h"


@class SPBucket;

#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

typedef void(^SPChangeEnumerationBlockType)(NSDictionary *change, BOOL *stop);

typedef NS_ENUM(NSInteger, SPProcessorErrors) {
    SPProcessorErrorsDuplicateChange,           // Should Re-Sync
    SPProcessorErrorsInvalidChange,             // Should Re-Send all
    SPProcessorErrorsServerError,               // Change is enqueued for retry
    SPProcessorErrorsClientError                // Change is nuked
};

#pragma mark ====================================================================================
#pragma mark SPChangeProcessor
#pragma mark ====================================================================================

@interface SPChangeProcessor : NSObject

@property (nonatomic, strong, readonly) NSString	*label;
@property (nonatomic, strong, readonly) NSString	*clientID;
@property (nonatomic, assign, readonly) int			numChangesPending;
@property (nonatomic, assign, readonly) int			numKeysForObjectsWithMoreChanges;
@property (nonatomic, assign, readonly) BOOL        reachedMaxPendings;

- (id)initWithLabel:(NSString *)label clientID:(NSString *)clientID;

- (void)reset;

- (void)notifyRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket;
- (void)processRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket errors:(NSSet **)errors;

- (void)markObjectWithPendingChanges:(NSString *)key bucket:(SPBucket *)bucket;
- (NSDictionary *)processLocalObjectWithKey:(NSString *)key bucket:(SPBucket *)bucket;
- (NSDictionary *)processLocalDeletionWithKey:(NSString *)key;
- (NSDictionary *)processLocalBucketDeletion:(SPBucket *)bucket;

- (void)enumeratePendingChangesForBucket:(SPBucket *)bucket block:(SPChangeEnumerationBlockType)block;
- (void)enumerateQueuedChangesForBucket:(SPBucket *)bucket block:(SPChangeEnumerationBlockType)block;
- (void)enumerateRetryChangesForBucket:(SPBucket *)bucket block:(SPChangeEnumerationBlockType)block;

- (NSArray *)exportPendingChanges;

@end
