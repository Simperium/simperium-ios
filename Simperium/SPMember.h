//
//  SPMember.h
//  Simperium
//
//  Created by Michael Johnston on 11-02-12.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPDiffable.h"

@class SPManagedObject;

extern NSString * const OP_OP;
extern NSString * const OP_VALUE;
extern NSString * const OP_REPLACE;
extern NSString * const OP_LIST_INSERT;
extern NSString * const OP_LIST_DELETE;
extern NSString * const OP_OBJECT_ADD;
extern NSString * const OP_OBJECT_REMOVE;
extern NSString * const OP_INTEGER;
extern NSString * const OP_LIST;
extern NSString * const OP_OBJECT;
extern NSString * const OP_STRING;

@interface SPMember : NSObject {
	NSString *keyName;
	NSString *type;
    id modelDefaultValue;
}

@property (nonatomic, assign, readonly) NSString *keyName;
@property (nonatomic, assign, readonly) id modelDefaultValue;

-(id)initFromDictionary:(NSDictionary *)dict;
-(id)defaultValue;
-(NSDictionary *)diffForAddition:(id)data;
-(NSDictionary *)diffForReplacement:(id)data;
-(NSDictionary *)diffForRemoval;
-(id)getValueFromDictionary:(NSDictionary *)dict key:(NSString *)key object:(id<SPDiffable>)object;
-(void)setValue:(id)value forKey:(NSString *)key inDictionary:(NSMutableDictionary *)dict;
-(id)fromJSON:(id)value;
-(id)toJSON:(id)value;
-(NSDictionary *)diff:(id)thisValue otherValue:(id)otherValue;
-(id)applyDiff:(id)thisValue otherValue:(id)otherValue;
-(NSDictionary *)transform:(id)thisValue otherValue:(id)otherValue oldValue:(id)oldValue;

@end