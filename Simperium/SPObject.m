//
//  SPObject.m
//  Simperium
//
//  Created by Michael Johnston on 12-04-11.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPObject.h"
#import "SPGhost.h"


@interface SPObject ()
@property (nonatomic, strong) NSMutableDictionary *mutableStorage;
@end


@implementation SPObject

@synthesize dict;
@synthesize ghost;
@synthesize bucket;
@synthesize ghostData;
@synthesize version;

- (instancetype)init {
    return [self initWithDictionary:[NSMutableDictionary dictionary]];
}

- (instancetype)initWithDictionary:(NSMutableDictionary *)dictionary {
    self = [super init];
    if (self) {
        self.mutableStorage = dictionary;
        self.ghost = [SPGhost new];
    }
    return self;    
}

// TODO: need to swizzle setObject:forKey: to inform Simperium that data has changed
// This will also need to dynamically update the schema if applicable

// TODO: getters and setters for ghost, ghostData, simperiumKey and version should probably be locked

// These are needed to compose a dict
- (void)simperiumSetValue:(id)value forKey:(NSString *)key {
    dispatch_barrier_async(dispatch_get_main_queue(), ^{
        [self.mutableStorage setObject:value forKey:key];
    });
}

- (id)simperiumValueForKey:(NSString *)key {
    __block id obj;

    dispatch_block_t block = ^{
        obj = [self.mutableStorage objectForKey: key];
    };
    
    // Note: For thread safety reasons, let's use the dictionary just from the main thread
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }

    return obj;
}

- (void)loadMemberData:(NSDictionary *)data {
    dispatch_barrier_async(dispatch_get_main_queue(), ^{
        [self.mutableStorage setValuesForKeysWithDictionary:data];
    });
}

- (void)willBeRead {
    
}

- (NSDictionary *)dictionary {
    return [self.mutableStorage copy];
}

- (id)object {
    return [self.mutableStorage copy];
}

@end
