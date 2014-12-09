//
//  SPChange.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 12/5/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>



#pragma mark ====================================================================================
#pragma mark SPChange
#pragma mark ====================================================================================

@interface SPChange : NSObject

@property (nonatomic, strong,  readonly) NSString       *clientID;
@property (nonatomic, strong,  readonly) NSString       *simperiumKey;
@property (nonatomic, strong,  readonly) NSString       *changeID;
@property (nonatomic, strong,  readonly) NSString       *changeVersion;

@property (nonatomic, strong,  readonly) NSString       *startVersion;
@property (nonatomic, strong,  readonly) NSString       *endVersion;

@property (nonatomic, strong,  readonly) NSString       *operation;
@property (nonatomic, strong,  readonly) NSDictionary   *value;
@property (nonatomic, strong,  readonly) NSDictionary   *data;
@property (nonatomic, strong,  readonly) NSNumber       *errorCode;

// Helper Properties
@property (nonatomic, strong,  readonly) NSString       *namespacelessKey;
@property (nonatomic, assign, readwrite) NSInteger      retryCount;

// Derived Properties
- (BOOL)isAddOperation;
- (BOOL)isRemoveOperation;
- (BOOL)isModifyOperation;
- (BOOL)hasErrors;

// Serialization
- (NSDictionary *)toDictionary;
- (NSString *)toJsonString;

// Builders
+ (SPChange *)modifyChangeWithKey:(NSString *)key startVersion:(NSString *)startVersion value:(NSDictionary *)value;
+ (SPChange *)modifyChangeWithKey:(NSString *)key startVersion:(NSString *)startVersion data:(NSDictionary *)data;
+ (SPChange *)removeChangeWithKey:(NSString *)key;
+ (SPChange *)emptyChangeWithKey:(NSString *)key;

// Parsers
+ (SPChange *)changeWithDictionary:(NSDictionary *)dictionary localNamespace:(NSString *)localNamespace;
+ (NSArray *)changesFromArray:(NSArray *)array localNamespace:(NSString *)localNamespace;

@end
