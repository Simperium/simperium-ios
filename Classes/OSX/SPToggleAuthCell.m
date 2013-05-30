//
//  SPToggleAuthCell.m
//  Simplenote-OSX
//
//  Created by Rainieri Ventura on 3/19/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPToggleAuthCell.h"

@implementation SPToggleAuthCell

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)controlView
{
    NSMutableAttributedString *attrString = [title mutableCopy];
    
    [attrString beginEditing];
    
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    [ps setAlignment:NSCenterTextAlignment];
    
    NSNumber *us = [NSNumber numberWithInt:NSUnderlineStyleSingle];
    
    NSDictionary *attributesBtn = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSFont fontWithName:@"Helvetica Neue" size:12], NSFontAttributeName,
                                   [NSColor whiteColor], NSForegroundColorAttributeName,
                                   ps, NSParagraphStyleAttributeName,
                                   us, NSUnderlineStyleAttributeName,
                                   nil];
    
    NSAttributedString *coloredStringBtn = [[NSAttributedString alloc]
                                            initWithString:[title string] attributes:attributesBtn];
    
    [attrString endEditing];
    
    NSRect r = [super drawTitle:coloredStringBtn withFrame:NSOffsetRect(frame, 0.0f, -1.5f) inView:controlView];
    
    [NSGraphicsContext restoreGraphicsState];
    
    return r;
}

@end
