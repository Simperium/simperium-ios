//
//  SPAuthenticationWindowController.h
//  Simperium
//
//  Created by Michael Johnston on 7/20/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SPAuthenticator;
@class SPAuthenticationTextField;
@class SPAuthenticationValidator;

@interface SPAuthenticationWindowController : NSWindowController

@property (nonatomic, strong) SPAuthenticator           *authenticator;
@property (nonatomic, strong) SPAuthenticationValidator *validator;
@property (nonatomic, assign) BOOL                      optional;
@property (nonatomic, assign) BOOL                      signingIn;

- (IBAction)signUpAction:(id)sender;
- (IBAction)signInAction:(id)sender;

- (void)setSigningIn:(BOOL)signingIn;

@end
