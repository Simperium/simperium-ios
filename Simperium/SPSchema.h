//
//  SPSchema.h
//  Simperium
//
//  Created by Michael Johnston on 11-05-16.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPDiffable.h"

@class Simperium;
@class SPManagedObject;
@class SPMember;

extern NSString * const SPSchemaDefinitionMembersKey; // Should be the key to an array of SPMemeberDefinitionDictionaries

@interface SPSchema : NSObject {
    NSString *bucketName;
    NSMutableDictionary *members; // ALL members
    NSMutableArray *binaryMembers; // JUST binary members (for optimization)
    BOOL dynamic;
}



@property (nonatomic, copy) NSString *bucketName;
@property (nonatomic, strong) NSMutableDictionary *members;
@property (nonatomic, strong) NSMutableArray *binaryMembers;
@property BOOL dynamic;

-(id)initWithBucketName:(NSString *)name data:(NSDictionary *)definition;
-(SPMember *)memberForKey:(NSString *)memberName;
-(void)addMemberForObject:(id)object key:(NSString *)key;

@end
