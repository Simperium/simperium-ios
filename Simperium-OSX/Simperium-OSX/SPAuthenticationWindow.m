//
//  SPAuthenticationWindow.m
//  Simplenote-OSX
//
//  Created by Michael Johnston on 7/20/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPAuthenticationWindow.h"

@implementation SPAuthenticationWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag {
    if ((self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag])) {
        [self setAlphaValue:1.0];
        [self setOpaque:NO];
        [self setBackgroundColor:[NSColor clearColor]];
        [self setHasShadow:YES];
    }
    
    return self;
}

- (BOOL)canBecomeKeyWindow {
    return YES;
}

@end
