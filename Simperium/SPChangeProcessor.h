//
//  SPChangeProcessor.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-15.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPProcessorConstants.h"


@class SPBucket;

#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

typedef void(^SPChangeSuccessHandlerBlockType)(NSString *simperiumKey, NSString *version);
typedef void(^SPChangeErrorHandlerBlockType)(NSString *simperiumKey, NSString *version, NSError *error);
typedef void(^SPChangeEnumerationBlockType)(NSDictionary *change);

typedef NS_ENUM(NSInteger, SPProcessorErrors) {
    SPProcessorErrorsSentDuplicateChange,       // Should Re-Sync
    SPProcessorErrorsSentInvalidChange,         // Send Full Data: The backend couldn't apply our diff
    SPProcessorErrorsReceivedUnknownChange,     // No need to handle: We've received a change for an unknown entity
    SPProcessorErrorsReceivedInvalidChange,     // Should Redownload the Entity: We couldn't apply a remote diff
    SPProcessorErrorsEntityGhostIntegrity,      // Entity's Ghost Integrity has been compromised. We'll reload the remote entity
    SPProcessorErrorsClientOutOfSync,           // We received a change with an SV != local version: Reindex is required
    SPProcessorErrorsClientError,               // Should Nuke PendingChange: Catch-all client errors
    SPProcessorErrorsServerError                // Should Retry: Catch-all server errors
};


#pragma mark ====================================================================================
#pragma mark SPChangeProcessor
#pragma mark ====================================================================================

@interface SPChangeProcessor : NSObject

@property (nonatomic, strong, readonly) NSString    *label;
@property (nonatomic, strong, readonly) NSString    *clientID;
@property (nonatomic, assign, readonly) int         numChangesPending;
@property (nonatomic, assign, readonly) int         numKeysForObjectsWithMoreChanges;
@property (nonatomic, assign, readonly) int         numKeysForObjectToDelete;
@property (nonatomic, assign, readonly) BOOL        reachedMaxPendings;

- (instancetype)initWithLabel:(NSString *)label clientID:(NSString *)clientID;

- (void)reset;

- (void)notifyOfRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket;
- (void)processRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket successHandler:(SPChangeSuccessHandlerBlockType)successHandler errorHandler:(SPChangeErrorHandlerBlockType)errorHandler;

- (void)enqueueObjectForMoreChanges:(NSString *)key bucket:(SPBucket *)bucket;
- (void)enqueueObjectForDeletion:(NSString *)key bucket:(SPBucket *)bucket;
- (void)enqueueObjectForRetry:(NSString *)key bucket:(SPBucket *)bucket overrideRemoteData:(BOOL)overrideRemoteData;
- (void)discardPendingChanges:(NSString *)key bucket:(SPBucket *)bucket;

- (NSArray *)processLocalObjectsWithKeys:(NSSet *)keys bucket:(SPBucket *)bucket;
- (NSArray *)processLocalDeletionsWithKeys:(NSSet *)keys;
- (NSArray *)processLocalBucketsDeletion:(NSSet *)buckets;

- (void)enumeratePendingChangesForBucket:(SPBucket *)bucket block:(SPChangeEnumerationBlockType)block;
- (void)enumerateQueuedChangesForBucket:(SPBucket *)bucket block:(SPChangeEnumerationBlockType)block;
- (void)enumerateQueuedDeletionsForBucket:(SPBucket*)bucket block:(SPChangeEnumerationBlockType)block;
- (void)enumerateRetryChangesForBucket:(SPBucket *)bucket block:(SPChangeEnumerationBlockType)block;

- (BOOL)hasLocalChangesForKey:(NSString *)key;
- (NSArray *)exportPendingChanges;

@end
