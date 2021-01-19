//
//  SPThreadsafeMutableDictionary.h
//  Simperium
//
//  Created by Lantean on 1/14/21.
//  Copyright © 2021 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


#pragma mark - SPThreadsafeMutableDictionary

@interface SPThreadsafeMutableDictionary : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

- (NSArray<NSString *> *)allKeys;

- (void)setObject:(id)object forKey:(NSString *)key;
- (void)setValuesForKeysWithDictionary:(NSDictionary<NSString *, id> *)keyedValues;
- (id)objectForKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;

- (NSDictionary *)copyInternalStorage;

@end
