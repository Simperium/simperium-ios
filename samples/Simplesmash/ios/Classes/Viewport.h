//
//  Viewport.h
//  Simplesmash
//
//  Created by Michael Johnston on 12-04-26.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <Simperium/SPManagedObject.h>


@interface Viewport : SPManagedObject

@property (nonatomic, retain) NSNumber * x;
@property (nonatomic, retain) NSNumber * y;
@property (nonatomic, retain) NSString * kind;
@property (nonatomic, retain) NSString * orientation;

@end
