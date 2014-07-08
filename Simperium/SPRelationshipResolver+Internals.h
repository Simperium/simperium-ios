//
//  SPRelationshipResolver+Internals.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 4/23/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "SPRelationshipResolver.h"



#pragma mark ====================================================================================
#pragma mark Private Methods
#pragma mark ====================================================================================

@interface SPRelationshipResolver ()

#ifdef DEBUG

// Performs a block on the private queue, asynchronously
- (void)performBlock:(void (^)())block;

// Returns the number of pending relationships
- (NSInteger)countPendingRelationships;

// Returns the number of pending relationships between two keys
- (NSInteger)countPendingRelationshipsWithSourceKey:(NSString *)sourceKey andTargetKey:(NSString *)targetKey;

#endif

@end
