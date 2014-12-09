//
//  SPChange.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 12/5/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "SPChange.h"
#import "SPProcessorConstants.h"
#import "NSString+Simperium.h"
#import "JSONKit+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString * const CH_KEY              = @"id";
static NSString * const CH_ADD              = @"+";
static NSString * const CH_REMOVE           = @"-";
static NSString * const CH_MODIFY           = @"M";
static NSString * const CH_OPERATION        = @"o";
static NSString * const CH_VALUE            = @"v";
static NSString * const CH_START_VERSION    = @"sv";
static NSString * const CH_END_VERSION      = @"ev";
static NSString * const CH_CHANGE_VERSION   = @"cv";
static NSString * const CH_LOCAL_ID         = @"ccid";
static NSString * const CH_CLIENT_ID        = @"clientid";
static NSString * const CH_ERROR            = @"error";
static NSString * const CH_DATA             = @"d";
static NSString * const CH_EMPTY            = @"EMPTY";


#pragma mark ====================================================================================
#pragma mark SPChange
#pragma mark ====================================================================================

@implementation SPChange

- (instancetype)initWithDictionary:(NSDictionary *)dictionary localNamespace:(NSString *)localNamespace {
    self = [super init];
    if (self) {
        _clientID           = dictionary[CH_CLIENT_ID];
        _simperiumKey       = dictionary[CH_KEY];
        _changeID           = dictionary[CH_LOCAL_ID];
        _changeVersion      = dictionary[CH_CHANGE_VERSION];

        // Store versions as strings, but if they come off the wire as numbers, then handle that too
        _startVersion       = [self parseAsString:dictionary[CH_START_VERSION]];
        _endVersion         = [self parseAsString:dictionary[CH_END_VERSION]];
        
        _operation          = dictionary[CH_OPERATION];
        _value              = dictionary[CH_VALUE];
        _data               = dictionary[CH_DATA];
        _errorCode          = dictionary[CH_ERROR];
        
        // Nuke the Local Namespace
        _namespacelessKey   = [self removeNamespace:localNamespace fromKey:_simperiumKey];
        
#warning TODO: ccids?
    }
    
    return self;
}

- (instancetype)initWithKey:(NSString *)key
                  operation:(NSString *)operation
               startVersion:(NSString *)startVersion
                      value:(NSDictionary *)value
                       data:(NSDictionary *)data
{
    self = [super init];
    if (self) {
        _simperiumKey       = key;
        _namespacelessKey   = key;
        _changeID           = [NSString sp_makeUUID];
        _startVersion       = startVersion;
        _operation          = operation;
        _value              = value;
        _data               = data;
    }
    
    return self;
}


#pragma mark - Derived Properties

- (BOOL)isAddOperation {
    return [self.operation isEqualToString:CH_ADD];
}

- (BOOL)isRemoveOperation {
    return [self.operation isEqualToString:CH_REMOVE];
}

- (BOOL)isModifyOperation {
    return [self.operation isEqualToString:CH_MODIFY];
}

- (BOOL)hasErrors {
    return self.errorCode != nil;
}


#pragma mark - Serialization

- (NSDictionary *)toDictionary {    
    // The change applies to this particular entity instance, so use its unique key as an identifier
    NSMutableDictionary *change = [NSMutableDictionary dictionaryWithObject:self.simperiumKey forKey:CH_KEY];
    
    // Every change must be marked with a unique ID
    change[CH_LOCAL_ID] = self.changeID;

    // Set the change's operation
    change[CH_OPERATION] = self.operation;

    // Set the data as the value for the operation (e.g. a diff dictionary for modify operations)
    if (self.data) {
        change[CH_DATA] = self.data;
    }

    // Set the data as the value for the operation (e.g. a diff dictionary for modify operations)
    if (self.value) {
        change[CH_VALUE] = self.value;
    }

    // If it's a modify operation, also include the object's version as the last known version
    if (self.isModifyOperation && self.startVersion.intValue != 0) {
        change[CH_START_VERSION] = self.startVersion;
    }
    
    return change;
}

- (NSString *)toJsonString {
    return [self.toDictionary sp_JSONString];
}


#pragma mark - Private Helpers

- (NSString *)parseAsString:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    
    if ([value isKindOfClass:[NSNumber class]]) {
        return [NSString stringWithFormat:@"%ld", (long)((NSNumber *)value).integerValue];
    }
    
    return nil;
}

- (NSString *)removeNamespace:(NSString *)namespace fromKey:(NSString *)simperiumKey {
    if (!namespace) {
        return simperiumKey;
    }
    
    NSString *theNamespace = [namespace stringByAppendingString:@"/"];
    return [simperiumKey stringByReplacingOccurrencesOfString:theNamespace withString:@""];
}


#pragma mark - Builders

+ (SPChange *)modifyChangeWithKey:(NSString *)key startVersion:(NSString *)startVersion value:(NSDictionary *)value {
    return [[SPChange alloc] initWithKey:key operation:CH_MODIFY startVersion:startVersion value:value data:nil];
}

+ (SPChange *)modifyChangeWithKey:(NSString *)key startVersion:(NSString *)startVersion data:(NSDictionary *)data {
    return [[SPChange alloc] initWithKey:key operation:CH_MODIFY startVersion:startVersion value:nil data:data];
}

+ (SPChange *)removeChangeWithKey:(NSString *)key {
    return [[SPChange alloc] initWithKey:key operation:CH_REMOVE startVersion:nil value:nil data:nil];
}

+ (SPChange *)emptyChangeWithKey:(NSString *)key {
    return [[SPChange alloc] initWithKey:key operation:CH_EMPTY startVersion:nil value:nil data:nil];
}


#pragma mark - Parsers

+ (SPChange *)changeWithDictionary:(NSDictionary *)dictionary localNamespace:(NSString *)localNamespace {
    // Do not parse if there's nothing!
    if (!dictionary) {
        return nil;
    }
    
    return [[SPChange alloc] initWithDictionary:dictionary localNamespace:localNamespace];
}

+ (NSArray *)changesFromArray:(NSArray *)rawChanges localNamespace:(NSString *)localNamespace {
    NSMutableArray *parsed = [NSMutableArray array];
    
    for (NSDictionary *rawChange in rawChanges) {
        [parsed addObject:[[SPChange alloc] initWithDictionary:rawChange localNamespace:localNamespace]];
    }
    
    return parsed;
}

@end
