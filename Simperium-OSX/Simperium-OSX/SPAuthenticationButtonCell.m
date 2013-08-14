//
//  SPAuthenticationButtonCell.m
//  Simplenote-OSX
//
//  Created by Michael Johnston on 7/24/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPAuthenticationButtonCell.h"
#import "SPAuthenticationConfiguration.h"

@implementation SPAuthenticationButtonCell


- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSBezierPath *outerClip = [NSBezierPath bezierPathWithRoundedRect:cellFrame xRadius:12.f yRadius:12.f];
    [outerClip addClip];
    
    if (![self isHighlighted])
        [[NSColor colorWithCalibratedRed:65.f/255.f green:137.f/255.f blue:199.f/255.f alpha:1.0] setFill];
    else
        [[NSColor colorWithCalibratedRed:55.f/255.f green:117.f/255.f blue:179.f/255.f alpha:1.0] setFill];
    
    [outerClip fill];

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setAlignment:NSCenterTextAlignment];

    int fontSize = 20;
    NSDictionary *attributes = @{NSFontAttributeName : [[SPAuthenticationConfiguration sharedInstance] regularFontWithSize:fontSize],
                                 NSForegroundColorAttributeName : [NSColor whiteColor],
                                 NSParagraphStyleAttributeName: style};
    
    NSAttributedString *buttonTitle = [[NSAttributedString alloc] initWithString:self.title attributes:attributes];
    
    // Vertically align the text (could be cached)
    CGFloat fieldHeight = [[SPAuthenticationConfiguration sharedInstance] regularFontHeightForSize:fontSize];
    CGFloat fieldY = (controlView.frame.size.height - fieldHeight) / 2.5;
    cellFrame.origin.y = fieldY;
    [buttonTitle drawInRect:cellFrame];
}

@end
