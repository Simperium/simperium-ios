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

@interface SPSchema : NSObject {
    NSString *bucketName;
    NSMutableArray *members; // ALL members
    NSMutableArray *binaryMembers; // JUST binary members (for optimization)
    BOOL dynamic;
}

@property (nonatomic, copy) NSString *bucketName;
@property (nonatomic, retain) NSMutableArray *members;
@property (nonatomic, retain) NSMutableArray *binaryMembers;
@property (assign) BOOL dynamic;

-(id)initWithBucketName:(NSString *)name data:(NSDictionary *)definition;
-(SPMember *)memberNamed:(NSString *)memberName;
-(void)setDefaults:(id<SPDiffable>)object;
-(void)addMemberForObject:(id)object key:(NSString *)key;

@end
