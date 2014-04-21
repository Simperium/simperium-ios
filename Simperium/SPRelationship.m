//
//  SPRelationship.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 4/21/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "SPRelationship.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString * const SPRelationshipsSourceKey        = @"SPRelationshipsSourceKey";
static NSString * const SPRelationshipsSourceBucket     = @"SPRelationshipsSourceBucket";
static NSString * const SPRelationshipsSourceAttribute  = @"SPRelationshipsSourceAttribute";
static NSString * const SPRelationshipsTargetBucket     = @"SPRelationshipsTargetBucket";
static NSString * const SPRelationshipsTargetKey        = @"SPRelationshipsTargetKey";

static NSString * const SPLegacyPathKey                 = @"SPPathKey";
static NSString * const SPLegacyPathBucket              = @"SPPathBucket";
static NSString * const SPLegacyPathAttribute           = @"SPPathAttribute";


#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPRelationship ()
@property (nonatomic, strong) NSString *sourceKey;
@property (nonatomic, strong) NSString *sourceAttribute;
@property (nonatomic, strong) NSString *sourceBucket;
@property (nonatomic, strong) NSString *targetKey;
@property (nonatomic, strong) NSString *targetBucket;
@end


#pragma mark ====================================================================================
#pragma mark SPRelationship
#pragma mark ====================================================================================

@implementation SPRelationship

- (instancetype)initWithSourceKey:(NSString *)sourceKey
                  sourceAttribute:(NSString *)sourceAttribute
                     sourceBucket:(NSString *)sourceBucket
                        targetKey:(NSString *)targetKey
                     targetBucket:(NSString *)targetBucket {
    
    NSAssert(sourceKey.length,         @"Invalid Parameter");
    NSAssert(sourceAttribute.length,   @"Invalid Parameter");
    NSAssert(sourceBucket.length,      @"Invalid Parameter");
    NSAssert(targetKey.length,         @"Invalid Parameter");
    
    if ((self = [super init])) {
        self.sourceKey          = sourceKey;
        self.sourceAttribute    = sourceAttribute;
        self.sourceBucket       = sourceBucket;
        self.targetKey          = targetKey;
        self.targetBucket       = targetBucket;
    }
    
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    
    SPRelationship *second = (SPRelationship *)object;
    return  [self.sourceKey isEqual:second.sourceKey] &&
            [self.sourceAttribute isEqual:second.sourceAttribute] &&
            [self.sourceBucket isEqual:second.sourceBucket] &&
            [self.targetBucket isEqual:second.targetBucket] &&
            [self.targetKey isEqual:second.targetKey];
}

- (NSUInteger)hash {
    return  [self.sourceKey         hash] +
            [self.sourceAttribute   hash] +
            [self.sourceBucket      hash] +
            [self.targetKey         hash] +
            [self.targetBucket      hash];
}

- (NSDictionary *)toDictionary {
    return @{
        SPRelationshipsSourceKey        : self.sourceKey,
        SPRelationshipsSourceBucket     : self.sourceBucket,
        SPRelationshipsSourceAttribute  : self.sourceAttribute,
        SPRelationshipsTargetBucket     : self.targetBucket,
        SPRelationshipsTargetKey        : self.targetKey
    };
}

+ (NSArray *)serializeToArray:(NSArray *)relationships {
    
    NSMutableArray *serialized = [NSMutableArray array];
    for (SPRelationship *relationship in relationships) {
        [serialized addObject:[relationship toDictionary]];
    }
    
    return serialized;
}

+ (NSArray *)parseFromArray:(NSArray *)rawRelationships {
    
    NSMutableArray *parsed = [NSMutableArray array];
    
    for (NSDictionary *rawRelationship in rawRelationships) {
        NSAssert([rawRelationship isKindOfClass:[NSDictionary class]], @"Invalid Parameter");
        
        SPRelationship *relationship = [[[self class] alloc] initWithSourceKey:rawRelationship[SPRelationshipsSourceKey]
                                                               sourceAttribute:rawRelationship[SPRelationshipsSourceAttribute]
                                                                  sourceBucket:rawRelationship[SPRelationshipsSourceBucket]
                                                                     targetKey:rawRelationship[SPRelationshipsTargetKey]
                                                                  targetBucket:rawRelationship[SPRelationshipsTargetBucket]];
        
        [parsed addObject:relationship];
    }

    return parsed;
}

+ (NSArray *)parseFromLegacyDictionary:(NSDictionary *)rawLegacy {

    NSMutableArray *parsed = [NSMutableArray array];
    
    for (NSString *targetKey in [rawLegacy allKeys]) {
        NSArray *relationships = rawLegacy[targetKey];
        NSAssert([relationships isKindOfClass:[NSArray class]], @"Invalid Kind");
        
        for (NSDictionary *legacy in relationships) {
            SPRelationship *relationship = [SPRelationship relationshipFromObjectWithKey:legacy[SPLegacyPathKey]
                                                                            andAttribute:legacy[SPLegacyPathAttribute]
                                                                                inBucket:legacy[SPLegacyPathBucket]
                                                                         toObjectWithKey:targetKey
                                                                                inBucket:@""];
            
            [parsed addObject:relationship];
        }
    }
    
    return parsed;
}

+ (instancetype)relationshipFromObjectWithKey:(NSString *)sourceKey
                                 andAttribute:(NSString *)sourceAttribute
                                     inBucket:(NSString *)sourceBucket
                              toObjectWithKey:(NSString *)targetKey
                                     inBucket:(NSString *)targetBucket {
    
    return [[[self class] alloc] initWithSourceKey:sourceKey
                                   sourceAttribute:sourceAttribute
                                      sourceBucket:sourceBucket
                                         targetKey:targetKey
                                      targetBucket:targetBucket];
}

@end
