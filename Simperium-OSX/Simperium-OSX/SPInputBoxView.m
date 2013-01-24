//
//  SPInputBoxView.m
//  Simplenote-OSX
//
//  Created by Rainieri Ventura on 2/24/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPInputBoxView.h"

@implementation SPInputBoxView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor whiteColor] setFill];
    NSRectFill(dirtyRect);
}

@end
