//
//  SPObject.m
//  Simperium
//
//  Created by Michael Johnston on 12-04-11.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPObject.h"
#import "SPGhost.h"
#import "SPBucket+Internals.h"
#import "SPSchema.h"
#import "SPThreadsafeMutableDictionary.h"


@interface SPObject ()
@property (nonatomic, strong) SPThreadsafeMutableDictionary *mutableStorage;
@end


@implementation SPObject

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
        self.mutableStorage = [[SPThreadsafeMutableDictionary alloc] initWithDictionary:dictionary];
        self.ghost = [SPGhost new];
    }
    return self;    
}

// TODO: need to swizzle setObject:forKey: to inform Simperium that data has changed
// This will also need to dynamically update the schema if applicable

// TODO: getters and setters for ghost, ghostData, simperiumKey and version should probably be locked

- (void)simperiumSetValue:(id)value forKey:(NSString *)key {
    [self.mutableStorage setObject:value forKey:key];
    [self.bucket.schema ensureDynamicMemberExistsForObject:value key:key];
}

- (id)simperiumValueForKey:(NSString *)key {
    return [self.mutableStorage objectForKey: key];
}

- (void)loadMemberData:(NSDictionary *)data {
    [self.mutableStorage setValuesForKeysWithDictionary:data];
    [self ensureSchemaMembersAreAdded];
}

- (void)ensureSchemaMembersAreAdded {
    for (NSString *key in self.mutableStorage.allKeys) {
        id value = [self.mutableStorage objectForKey:key];
        if (value == nil) {
            continue;
        }

        [self.bucket.schema ensureDynamicMemberExistsForObject:value key:key];
    }
}

- (void)willBeRead {
    
}

- (NSDictionary *)dictionary {
    return [self.mutableStorage copyInternalStorage];
}

- (id)object {
    return [self.mutableStorage copyInternalStorage];
}

@end
