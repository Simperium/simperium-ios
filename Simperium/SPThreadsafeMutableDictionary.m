//
//  SPThreadsafeMutableDictionary.m
//  Simperium
//
//  Created by Lantean on 1/14/21.
//  Copyright © 2021 Simperium. All rights reserved.
//

#import "SPThreadsafeMutableDictionary.h"



#pragma mark - Private

@interface SPThreadsafeMutableDictionary ()
@property (nonatomic, strong) NSMutableDictionary   *contents;
@property (nonatomic, strong) dispatch_queue_t      queue;
@end


#pragma mark - SPThreadsafeMutableDictionary

@implementation SPThreadsafeMutableDictionary

- (instancetype)init {
    self = [super init];
    if (self) {
        self.contents = [NSMutableDictionary dictionary];
        self.queue = dispatch_queue_create("com.simperium.SPThreadsafeMutableDictionary", NULL);
    }

    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (self && dictionary != nil) {
        [self.contents addEntriesFromDictionary:dictionary];
    }

    return self;
}

- (NSArray<NSString *> *)allKeys {
    __block NSArray *allKeys = nil;
    dispatch_sync(self.queue, ^{
        allKeys = self.contents.allKeys;
    });

    return allKeys;
}

- (void)setObject:(id)object forKey:(NSString *)key {
    dispatch_sync(self.queue, ^{
        if (!object) {
            [self.contents removeObjectForKey:key];
            return;
        }
        [self.contents setObject:object forKey:key];
    });
}

- (void)setValuesForKeysWithDictionary:(NSDictionary<NSString *, id> *)keyedValues {
    dispatch_sync(self.queue, ^{
        [self.contents setValuesForKeysWithDictionary:keyedValues];
    });
}

- (id)objectForKey:(NSString *)key {
    __block id object = nil;
    dispatch_sync(self.queue, ^{
        object = [self.contents objectForKey:key];
    });
    return object;
}

- (void)removeObjectForKey:(NSString *)key {
    dispatch_sync(self.queue, ^{
        [self.contents removeObjectForKey:key];
    });
}

- (NSDictionary *)copyInternalStorage {
    __block id output = nil;
    dispatch_sync(self.queue, ^{
        output = [self.contents copy];
    });
    return output;
}

@end
