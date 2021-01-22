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

@interface SPJSONStorage : SPStorage<SPStorageProvider>

@property (nonatomic, strong) NSMutableDictionary                   *objects;
@property (nonatomic, strong) NSMutableDictionary                   *allObjects;
@property (nonatomic, strong) NSDictionary<NSString *, SPBucket *>  *buckets;

- (instancetype)initWithDelegate:(id<SPStorageObserver>)aDelegate;

@end
