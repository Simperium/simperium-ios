//
//  SPAuthWindowController.h
//  Simplenote-OSX
//
//  Created by Rainieri Ventura on 2/22/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SPAuthenticationManager;

@interface SPAuthWindowController : NSWindowController
{
    SPAuthenticationManager *_authManager;
    IBOutlet NSTextFieldCell *signinText;
    IBOutlet NSButton *signinButton;
    IBOutlet NSTextField *emailField;
    IBOutlet NSTextField *passwordField;
    IBOutlet NSMenuItem *logout;
}

@property (nonatomic, retain) SPAuthenticationManager *authManager;

- (IBAction)signinClicked:(id)sender;
- (id)initWithWindowNibName:(NSString *)windowName;

@end
