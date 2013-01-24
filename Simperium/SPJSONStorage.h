//
//  SPJSONStorage.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-17.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPStorage.h"
#import "SPStorageObserver.h"
#import "SPStorageProvider.h"

@interface SPJSONStorage : SPStorage<SPStorageProvider> {
    id<SPStorageObserver> delegate;
    NSMutableDictionary *objects;
    NSMutableDictionary *allObjects;
    NSMutableArray *objectList;
    dispatch_queue_t storageQueue;
}

@property (nonatomic, retain) NSMutableDictionary *objects;
@property (nonatomic, retain) NSMutableDictionary *ghosts;
@property (nonatomic, retain) NSMutableArray *objectList;
@property (nonatomic, retain) NSMutableDictionary *allObjects;

-(id)initWithDelegate:(id<SPStorageObserver>)aDelegate;

@end
