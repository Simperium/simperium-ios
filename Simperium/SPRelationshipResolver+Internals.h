//
//  SPRelationshipResolver+Internals.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 4/23/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "SPRelationshipResolver.h"



typedef void(^SPResolverCompletionBlockType)();

#pragma mark ====================================================================================
#pragma mark Private Methods
#pragma mark ====================================================================================

@interface SPRelationshipResolver ()

#ifdef DEBUG

- (void)resolvePendingRelationshipsForKey:(NSString *)simperiumKey
                               bucketName:(NSString *)bucketName
                                  storage:(id<SPStorageProvider>)storage
                               completion:(SPResolverCompletionBlockType)completion;

- (NSInteger)countPendingRelationships;

- (NSInteger)countPendingRelationshipsWithSourceKey:(NSString *)sourceKey
                                       andTargetKey:(NSString *)targetKey;

- (BOOL)verifyBidirectionalMappingBetweenKey:(NSString *)sourceKey
                                      andKey:(NSString *)targetKey;

#endif

@end
