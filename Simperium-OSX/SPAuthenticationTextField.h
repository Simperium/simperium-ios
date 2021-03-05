//
//  SPAuthenticationTextField.h
//  Simplenote-OSX
//
//  Created by Michael Johnston on 7/24/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SPAuthenticationTextField : NSView

@property (nonatomic,  strong, readonly) NSTextField                *textField;
@property (nonatomic,   weak, readwrite) id<NSTextFieldDelegate>    delegate;
@property (nonatomic,   copy, readwrite) NSString                   *stringValue;
@property (nonatomic,   copy, readwrite) NSString                   *placeholderString;
@property (nonatomic, assign, readwrite) BOOL                       isEnabled;

- (instancetype)initWithFrame:(NSRect)frame secure:(BOOL)secure;

@end
