//
//  Stat.h
//  Simplestat
//
//  Created by Simplestat on 4/6/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <Simperium/SPManagedObject.h>


@interface Stat : SPManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * value;

@end
