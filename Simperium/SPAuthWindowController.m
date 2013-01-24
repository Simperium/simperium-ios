//
//  SPAuthWindowController.m
//  Simplenote-OSX
//
//  Created by Rainieri Ventura on 2/22/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPAuthWindowController.h"
#import "SPAuthenticationManager.h"

@implementation SPAuthWindowController
@synthesize authManager = _authManager;

- (id)initWithWindowNibName:(NSString *)windowName;
{
    self = [super initWithWindowNibName:windowName];
    if (self) {
    }
    
    return self;
}

- (void)dealloc {
    self.authManager = nil;
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    //Header
    [signinText setBackgroundStyle:NSBackgroundStyleLowered];

    //Button
    [[signinButton cell]setBackgroundStyle:NSBackgroundStyleLowered];
    
    
}

- (IBAction)signinClicked:(id)sender{
    [self.authManager authenticateWithUsername:[emailField stringValue] password:[passwordField stringValue]
                       success:^{
                           
                       }
                       failure:^(int responseCode, NSString *responseString){
                       }
     ];
}

@end
