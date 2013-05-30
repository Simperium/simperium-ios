//
//  Config.h
//  Simpletrek
//
//  Created by Michael Johnston on 11-03-08.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TestObject.h"

@interface Config : TestObject {
	NSNumber *warpSpeed;
    NSString *binaryFile;
    NSString *captainsLog;
    NSNumber *shieldsUp;
    UIColor *shieldColor;
    NSNumber *syncingEnabled;
    NSNumber *shieldPercent;
    NSDecimalNumber *cost;
    UIImage *smallImageTest;
    NSDate *date;
}

@property (nonatomic, retain) NSNumber *warpSpeed;
@property (nonatomic, retain) NSString *binaryFile;
@property (nonatomic, retain) NSString *captainsLog;
@property (nonatomic, retain) NSNumber *shieldsUp;
@property (nonatomic, retain) UIColor *shieldColor;
@property (nonatomic, retain) NSNumber *shieldPercent;
@property (nonatomic, retain) NSDecimalNumber *cost;
@property (nonatomic, retain) UIImage *smallImageTest;
@property (nonatomic, retain) NSDate *date;

@end
