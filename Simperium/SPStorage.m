//
//  SPStorage.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-17.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPStorage.h"
#import "SPGhost.h"
#import "NSString+Simperium.h"
#import "SPLogger.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static SPLogLevels logLevel = SPLogLevelsInfo;


#pragma mark ====================================================================================
#pragma mark SPStorage
#pragma mark ====================================================================================

@implementation SPStorage

- (void)stopManagingObjectWithKey:(NSString *)key
{    
    // TODO: check pendingReferences as well just in case? And the stash...    
}

- (void)configureNewGhost:(id<SPDiffable>)object
{
    // It's new to this client, so create an empty ghost for it with version 0
    // (objects coming off the wire already have a ghost, so be careful not to stomp it)
    if (object.ghost != nil) {
        return;
    }
    
    SPGhost *ghost = [[SPGhost alloc] initWithKey: object.simperiumKey memberData: nil];
    object.ghost = ghost;
    object.ghost.version = @"0";
}

- (void)configureInsertedObject:(id<SPDiffable>)object
{
    if (object.simperiumKey == nil || object.simperiumKey.length == 0) {
        NSString *key = nil;
        
        if ([object respondsToSelector:@selector(getSimperiumKeyFromLegacyKey)]) {
            key = [object performSelector:@selector(getSimperiumKeyFromLegacyKey)];
            SPLogVerbose(@"Simperium initializing entity with legacy key: %@", key);
        }
        
        object.simperiumKey = (key.length != 0 ? key : [NSString sp_makeUUID]);
    }
    
    [self configureNewGhost:object];
}

- (void)configureInsertedObjects:(NSSet *)insertedObjects
{
    for (NSObject *insertedObject in insertedObjects) {
        if ([insertedObject conformsToProtocol:@protocol(SPDiffable)]) {
            [self configureInsertedObject:(id<SPDiffable>)insertedObject];
        }
    }
}

@end
