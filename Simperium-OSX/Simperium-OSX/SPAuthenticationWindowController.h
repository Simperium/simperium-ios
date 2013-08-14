//
//  AuthWindowController.h
//  Simplenote-OSX
//
//  Created by Michael Johnston on 7/20/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Simperium-OSX/SPAuthenticationManager.h>

@class SPAuthenticationTextField;
@class SPAuthenticationValidator;

@interface SPAuthenticationWindowController : NSWindowController<NSTextFieldDelegate> {
    NSImageView *logoImageView;
    NSButton *cancelButton;
    SPAuthenticationTextField *usernameField;
    SPAuthenticationTextField *passwordField;
    SPAuthenticationTextField *confirmField;
    NSTextField *changeToSignInField;
    NSTextField *changeToSignUpField;
    NSTextField *errorField;
    NSButton *signInButton;
    NSButton *signUpButton;
    NSButton *changeToSignInButton;
    NSButton *changeToSignUpButton;
    NSProgressIndicator *signInProgress;
    NSProgressIndicator *signUpProgress;
    BOOL signingIn;
    BOOL optional;
    CGFloat rowSize;
}

@property (nonatomic, retain) SPAuthenticationManager *authManager;
@property (nonatomic, retain) SPAuthenticationValidator *validator;
@property (assign) BOOL optional;

- (IBAction) signUpAction:(id)sender;
- (IBAction) signInAction:(id)sender;

@end
