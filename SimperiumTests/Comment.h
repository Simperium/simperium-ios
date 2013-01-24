//
//  Comment.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-20.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPManagedObject.h"
#import "TestObject.h"

@class Post;

@interface Comment : TestObject

@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) Post *post;

@end
