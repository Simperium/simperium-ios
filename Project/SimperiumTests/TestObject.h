//
//  TestObject.h
//  Simpletrek
//
//  Created by Michael Johnston on 11-03-08.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "SPManagedObject.h"

@interface TestObject : SPManagedObject {
}



-(BOOL)isEqualToObject:(TestObject *)other;

@end
