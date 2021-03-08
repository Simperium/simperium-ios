//
//  SPAuthenticationTextField.m
//  Simplenote-OSX
//
//  Created by Michael Johnston on 7/24/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPAuthenticationTextField.h"
#import "SPAuthenticationConfiguration.h"



#pragma mark - SPAuthenticationTextField

@interface SPAuthenticationTextField()
@property (nonatomic, assign) BOOL secure;
@end

@implementation SPAuthenticationTextField

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(NSRect)frame secure:(BOOL)secure {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupInterface:secure];
    }

    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setupInterface:self.secure];
}

- (void)setupInterface:(BOOL)secure {
    NSRect frame = self.frame;
    CGFloat paddingX = 10;
    CGFloat fontSize = 20;
    CGFloat fieldHeight = [[SPAuthenticationConfiguration sharedInstance] regularFontHeightForSize:fontSize];
    CGFloat fieldY = (self.frame.size.height - fieldHeight) / 2;
    CGRect textFrame = NSMakeRect(paddingX, fieldY, frame.size.width-paddingX*2, fieldHeight);

    Class textFieldClass = secure ? [NSSecureTextField class] : [NSTextField class];
    _textField = [[textFieldClass alloc] initWithFrame:textFrame];
    NSFont *font = [NSFont fontWithName:[SPAuthenticationConfiguration sharedInstance].regularFontName size:fontSize];
    [_textField setFont:font];
    [_textField setTextColor:[NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
    [_textField setDrawsBackground:NO];
    [_textField setBezeled:NO];
    [_textField setBordered:NO];
    [_textField setFocusRingType:NSFocusRingTypeNone];
    [[_textField cell] setWraps:NO];
    [[_textField cell] setScrollable:YES];
    [self addSubview:_textField];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleTextFieldDidBeginEditing:) name:NSTextDidBeginEditingNotification object:nil];
    [nc addObserver:self selector:@selector(handleTextFieldDidFinishEditing:) name:NSTextDidEndEditingNotification object:nil];
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

- (NSString *)placeholderString {
    return [[_textField cell] placeholderString];
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

- (BOOL)isEnabled {
    return _textField.enabled;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath *betterBounds = [NSBezierPath bezierPathWithRect:self.bounds];
    [betterBounds addClip];

    if (self.sp_isFirstResponder) {
        [[NSColor colorWithCalibratedWhite:0.9 alpha:1.0] setFill];
        [betterBounds fill];

    } else {
        [[NSColor colorWithCalibratedWhite:250.f/255.f alpha:1.0] setFill];
        [betterBounds fill];

        [[NSColor colorWithCalibratedWhite:218.f/255.f alpha:1.0] setStroke];
        [betterBounds stroke];
    }
}

- (BOOL)sp_isFirstResponder {
    NSResponder *responder = [self.window firstResponder];
    if (![responder isKindOfClass:[NSText class]]) {
        return responder == self.textField;
    }

    NSText *fieldEditor = (NSText *)responder;
    return fieldEditor.delegate == (id<NSTextDelegate>)self.textField;
}


#pragma mark - Notification Helpers

- (void)handleTextFieldDidBeginEditing:(NSNotification *)note {
    [self setNeedsDisplay:YES];
}

- (void)handleTextFieldDidFinishEditing:(NSNotification *)note {
    [self setNeedsDisplay:YES];
}

@end
