//
//  SPRelationshipResolver.h
//  Simperium
//
//  Created by Michael Johnston on 2012-08-22.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPStorageProvider.h"
#import "SPRelationship.h"



#pragma mark ====================================================================================
#pragma mark SPRelationshipResolver
#pragma mark ====================================================================================

@interface SPRelationshipResolver : NSObject

- (void)loadPendingRelationships:(id<SPStorageProvider>)storage;

- (void)addPendingRelationship:(SPRelationship *)relationship;

- (void)resolvePendingRelationshipsForKey:(NSString *)simperiumKey
                               bucketName:(NSString *)bucketName
                                  storage:(id<SPStorageProvider>)storage;

- (void)saveWithStorage:(id<SPStorageProvider>)storage;

- (void)reset:(id<SPStorageProvider>)storage;

@end
