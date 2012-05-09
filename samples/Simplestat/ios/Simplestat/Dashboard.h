//
//  Dashboard.h
//  Simplestat
//
//  Created by Andy Gayton on 4/5/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <Simperium/SPManagedObject.h>

@interface Dashboard : SPManagedObject

@property (nonatomic, retain) NSString * name;

@end
