//
//  SPGraphViewController.h
//  Simplestat
//
//  Created by Michael Johnston on 12-04-25.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"
#import <Simperium/Simperium.h>

@class Stat;

@interface SPGraphViewController : UIViewController<CPTPlotDataSource, CPTAxisDelegate, SimperiumDelegate> {
    CPTXYGraph *graph;

    NSMutableArray *dataForPlot;
}
- (IBAction)done:(id)sender;

@property (strong, nonatomic) Stat *statItem;
@property (readwrite, retain, nonatomic) NSMutableArray *dataForPlot;

@end
