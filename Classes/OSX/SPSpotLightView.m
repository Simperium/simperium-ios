//
//  SPSpotLightView.m
//  Simplenote-OSX
//
//  Created by Rainieri Ventura on 2/23/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPSpotLightView.h"

@implementation SPSpotLightView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)drawRect:(NSRect)rect
{
    NSColor *startColor = [NSColor colorWithCalibratedWhite:0.0f alpha:0.2f];
    NSColor *endColor = [NSColor colorWithCalibratedWhite:1.0f alpha:0.2f];
    
    NSRect bounds = [self bounds];
    NSGradient* aGradient = [[NSGradient alloc]
                              initWithStartingColor:startColor
                              endingColor:endColor];

    NSPoint centerPoint = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    NSPoint otherPoint = NSMakePoint(centerPoint.x - 60.0, centerPoint.y + 95.0);
    CGFloat firstRadius = MIN( ((bounds.size.width/2.0) + 100.0),
                              ((bounds.size.height/2.0) + 100.0) );
    [aGradient drawFromCenter:centerPoint radius:firstRadius
                     toCenter:otherPoint radius:5.0
                      options:NSGradientDrawsAfterEndingLocation];
}

@end
