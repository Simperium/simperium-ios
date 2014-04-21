//
//  SPRelationship.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 4/21/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPRelationship : NSObject

@property (nonatomic, strong, readonly) NSString *sourceKey;
@property (nonatomic, strong, readonly) NSString *sourceAttribute;
@property (nonatomic, strong, readonly) NSString *sourceBucket;
@property (nonatomic, strong, readonly) NSString *targetKey;
@property (nonatomic, strong, readonly) NSString *targetBucket;

+ (NSArray *)serializeToArray:(NSArray *)relationships;

+ (NSArray *)parseFromArray:(NSArray *)rawRelationships;
+ (NSArray *)parseFromLegacyDictionary:(NSDictionary *)rawLegacy;

+ (instancetype)relationshipFromObjectWithKey:(NSString *)sourceKey
                                 andAttribute:(NSString *)sourceAttribute
                                     inBucket:(NSString *)sourceBucket
                              toObjectWithKey:(NSString *)targetKey
                                     inBucket:(NSString *)targetBucket;

@end
