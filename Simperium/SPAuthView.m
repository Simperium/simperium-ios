//
//  AuthWindowController.m
//  Simplenote-OSX
//
//  Created by Rainieri Ventura on 2/22/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "AuthView.h"

@implementation AuthView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    // set any NSColor for filling, say white:
    NSImage *image = [NSImage imageNamed:@"auth_bgnoise.png"];
    NSColor *noise = [NSColor colorWithPatternImage:image];
    [noise setFill];
    NSRectFill(dirtyRect);
}

@end
