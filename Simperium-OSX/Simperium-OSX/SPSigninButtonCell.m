//
//  SPSigninButton.m
//  Simplenote-OSX
//
//  Created by Rainieri Ventura on 2/23/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPSigninButtonCell.h"

@implementation SPSigninButtonCell

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSGraphicsContext *ctx = [NSGraphicsContext currentContext];
    
    CGFloat roundedRadius = 3.0f;
    
    // Outer stroke (drawn as gradient)
    
    [ctx saveGraphicsState];
    NSBezierPath *outerClip = [NSBezierPath bezierPathWithRoundedRect:frame 
                                                              xRadius:roundedRadius 
                                                              yRadius:roundedRadius];
    [outerClip setClip];
    
    NSGradient *outerGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                 [NSColor colorWithDeviceWhite:0.20f alpha:1.0f], 0.0f, 
                                 [NSColor colorWithDeviceWhite:0.21f alpha:1.0f], 1.0f, 
                                 nil];
    
    [outerGradient drawInRect:[outerClip bounds] angle:90.0f];
    [ctx restoreGraphicsState];
    
    // Background gradient
    
    [ctx saveGraphicsState];
    NSBezierPath *backgroundPath = 
    [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame, 1.3f, 1.3f) 
                                    xRadius:roundedRadius 
                                    yRadius:roundedRadius];
    [backgroundPath setClip];
    
    NSGradient *backgroundGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                      [NSColor colorWithCalibratedRed:0.0/255.0 
                                                                green:105.0/255.0
                                                                 blue:176.0/255.0
                                                                alpha:1.0f], 0.0f, 
                                      [NSColor colorWithCalibratedRed:42.0/255.0 
                                                                green:150.0/255.0
                                                                 blue:221.0/255.0
                                                                alpha:1.0f], 1.0f, 
                                      nil];
    
    [backgroundGradient drawInRect:[backgroundPath bounds] angle:270.0f];
    [ctx restoreGraphicsState];
    
    // Dark stroke
    
    [ctx saveGraphicsState];
    [[NSColor colorWithDeviceWhite:0.12f alpha:1.0f] setStroke];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame, 1.5f, 1.5f) 
                                     xRadius:roundedRadius 
                                     yRadius:roundedRadius] stroke];
    [ctx restoreGraphicsState];
    
    // Inner light stroke
    
    [ctx saveGraphicsState];
    [[NSColor colorWithDeviceWhite:1.0f alpha:0.05f] setStroke];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame, 2.5f, 2.5f) 
                                     xRadius:roundedRadius 
                                     yRadius:roundedRadius] stroke];
    [ctx restoreGraphicsState];        
    
    // Draw darker overlay if button is pressed
    
    if([self isHighlighted]) {
        [ctx saveGraphicsState];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame, 2.0f, 2.0f) 
                                         xRadius:roundedRadius 
                                         yRadius:roundedRadius] setClip];
        [[NSColor colorWithCalibratedWhite:0.0f alpha:0.35] setFill];
        NSRectFillUsingOperation(frame, NSCompositeSourceOver);
        [ctx restoreGraphicsState];
    }
}

- (void)drawImage:(NSImage*)image withFrame:(NSRect)frame inView:(NSView*)controlView
{
    NSGraphicsContext *ctx = [NSGraphicsContext currentContext];
    CGContextRef contextRef = [ctx graphicsPort];
    
    NSData *data = [image TIFFRepresentation]; // open for suggestions
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if(source) {
        CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CFRelease(source);
        
        // Draw shadow 1px below image
        
        CGContextSaveGState(contextRef);
        {
            NSRect rect = NSOffsetRect(frame, 0.0f, 1.0f);
            CGFloat white = [self isHighlighted] ? 0.2f : 0.35f;
            CGContextClipToMask(contextRef, NSRectToCGRect(rect), imageRef);
            [[NSColor colorWithDeviceWhite:white alpha:1.0f] setFill];
            NSRectFill(rect);
        } 
        CGContextRestoreGState(contextRef);
        
        // Draw image
        
        CGContextSaveGState(contextRef);
        {
            NSRect rect = frame;
            CGContextClipToMask(contextRef, NSRectToCGRect(rect), imageRef);
            [[NSColor colorWithDeviceWhite:0.1f alpha:1.0f] setFill];
            NSRectFill(rect);
        } 
        CGContextRestoreGState(contextRef);        
        
        CFRelease(imageRef);
    }
    
}

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)controlView
{
    
    NSMutableAttributedString *attrString = [title mutableCopy];

    [attrString beginEditing];

    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    [ps setAlignment:NSCenterTextAlignment];
    
    NSDictionary *attributesBtn = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSFont fontWithName:@"Helvetica Neue" size:12], NSFontAttributeName,
                                   [NSColor whiteColor], NSForegroundColorAttributeName,
                                   ps, NSParagraphStyleAttributeName,
                                   nil];
    
    NSAttributedString *coloredStringBtn = [[NSAttributedString alloc]
                                            initWithString:[title string] attributes:attributesBtn];
    
    [attrString endEditing];
    
    NSRect r = [super drawTitle:coloredStringBtn withFrame:NSOffsetRect(frame, 0.0f, -1.5f) inView:controlView];
        
    [NSGraphicsContext restoreGraphicsState];
    
    return r;
    
}

@end
