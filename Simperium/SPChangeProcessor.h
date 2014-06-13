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

typedef void(^SPChangeErrorHandlerBlockType)(NSString *simperiumKey, NSNumber *version, NSError *error);
typedef void(^SPChangeEnumerationBlockType)(NSDictionary *change);

typedef NS_ENUM(NSInteger, SPProcessorErrors) {
    SPProcessorErrorsDuplicateChange,           // Should Re-Sync
    SPProcessorErrorsInvalidLocalChange,        // Should Retry, by sending the full data
    SPProcessorErrorsInvalidRemoteChange,       // Should Redownload the Entity
    SPProcessorErrorsServerError,               // Should Retry
    SPProcessorErrorsClientError                // Should Nuke PendingChange
};

NSString * const CH_KEY;
NSString * const CH_ADD;
NSString * const CH_REMOVE;
NSString * const CH_MODIFY;
NSString * const CH_OPERATION;
NSString * const CH_VALUE;
NSString * const CH_START_VERSION;
NSString * const CH_END_VERSION;
NSString * const CH_CHANGE_VERSION;
NSString * const CH_LOCAL_ID;
NSString * const CH_CLIENT_ID;
NSString * const CH_ERROR;
NSString * const CH_DATA;
NSString * const CH_EMPTY;


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

- (void)notifyOfRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket;
- (void)processRemoteChanges:(NSArray *)changes bucket:(SPBucket *)bucket errorHandler:(SPChangeErrorHandlerBlockType)errorHandler;

- (BOOL)processRemoteEntityWithKey:(NSString *)simperiumKey version:(NSString *)version data:(NSDictionary *)data bucket:(SPBucket *)bucket;

- (void)enqueueObjectForMoreChanges:(NSString *)key bucket:(SPBucket *)bucket;
- (void)enqueueObjectForRetry:(NSString *)key bucket:(SPBucket *)bucket overrideRemoteData:(BOOL)overrideRemoteData;
- (void)discardPendingChanges:(NSString *)key bucket:(SPBucket *)bucket;

- (NSArray *)processLocalObjectsWithKeys:(NSSet *)keys bucket:(SPBucket *)bucket;
- (NSArray *)processLocalDeletionsWithKeys:(NSSet *)keys;
- (NSArray *)processLocalBucketsDeletion:(NSSet *)buckets;

- (void)enumeratePendingChangesForBucket:(SPBucket *)bucket block:(SPChangeEnumerationBlockType)block;
- (void)enumerateQueuedChangesForBucket:(SPBucket *)bucket block:(SPChangeEnumerationBlockType)block;
- (void)enumerateRetryChangesForBucket:(SPBucket *)bucket block:(SPChangeEnumerationBlockType)block;

- (NSArray *)exportPendingChanges;

@end
