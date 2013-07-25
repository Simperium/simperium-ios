//
//  SPAuthenticationTextField.m
//  Simplenote-OSX
//
//  Created by Michael Johnston on 7/24/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPAuthenticationTextField.h"

@interface SPAuthenticationTextField() {
    BOOL hasFocus;
}

@end

@implementation SPAuthenticationTextField

- (id)initWithFrame:(NSRect)frame secure:(BOOL)secure {
    self = [super initWithFrame:frame];
    if (self) {
        Class textFieldClass = secure ? [NSSecureTextField class] : [NSTextField class];
        CGRect textFrame = NSMakeRect(10, -4, frame.size.width-20, frame.size.height);
        _textField = [[textFieldClass alloc] initWithFrame:textFrame];
        [_textField setFont:[NSFont fontWithName:@"SourceSansPro-Regular" size:20]];
        [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
        [_textField setDrawsBackground:NO];
        [_textField setBezeled:NO];
        [_textField setBordered:NO];
        [_textField setFocusRingType:NSFocusRingTypeNone];
        [self addSubview:_textField];
    }
    
    return self;
}

- (void)setStringValue:(NSString *)string {
    _textField.stringValue = string;
}

- (NSString *)stringValue {
    return _textField.stringValue;
}

- (void)setPlaceholderString:(NSString *)string {
    [[_textField cell] setPlaceholderString:string];
}

- (void)setDelegate:(id)delegate {
    _textField.delegate = delegate;
}

- (id)delegate {
    return _textField.delegate;
}

- (void)setEnabled:(BOOL)enabled {
    [_textField setEnabled:enabled];
    [_textField setEditable:enabled];
}

- (BOOL)hasFirstResponder {
	BOOL hasFirstResponder = NO;
	
	hasFirstResponder = ([[[_textField window] firstResponder] isKindOfClass:[NSTextView class]]
			   && [[_textField window] fieldEditor:NO forObject:nil]!=nil
			   && [_textField isEqualTo:(id)[(NSTextView *)[[_textField window] firstResponder]delegate]]);
	
	return hasFirstResponder;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath *betterBounds = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:12.0 yRadius:12.0];
    [betterBounds addClip];
    
    
    if ([self hasFirstResponder]) {
        [[NSColor colorWithCalibratedWhite:0.9 alpha:1.0] setFill];
        [betterBounds fill];

        
        //        [[NSColor colorWithCalibratedRed:65.f/255.f green:137.f/255.f blue:200.f/255.f alpha:1.0] setStroke];
//        [betterBounds setLineWidth:4.0];
//        [betterBounds stroke];
        
        if (!hasFocus) {
            hasFocus = YES;
            [self setNeedsDisplay:YES];
        }
    } else {
        [[NSColor colorWithCalibratedWhite:250.f/255.f alpha:1.0] setFill];
        [betterBounds fill];

        
        [[NSColor colorWithCalibratedWhite:218.f/255.f alpha:1.0] setStroke];
        [betterBounds stroke];
        
        if (hasFocus) {
            hasFocus = NO;
            [self setNeedsDisplay:YES];
        }
    }
}

//+ (void)load {
//    [SPAuthenticationTextField setCellClass:[SPAuthenticationTextFieldCell class]];
//}

@end
