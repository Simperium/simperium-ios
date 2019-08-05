//
//  SPAuthenticationViewController.h
//  Simperium
//
//  Created by Michael Johnston on 24/11/11.
//  Copyright 2011 Simperium. All rights reserved.
//
//  You can write a subclass of SPAuthenticationViewController and then set authenticationViewControllerClass
//  on your Simperium instance in order to fully customize the behavior of the authentication UI.
//
//  Simperium will use the subclass and display your UI automatically.

#import <UIKit/UIKit.h>


@class SPAuthenticator;

#pragma mark ====================================================================================
#pragma mark SPAuthenticationViewController
#pragma mark ====================================================================================

@interface SPAuthenticationViewController <SPAuthenticationInterface> : UIViewController

@property (nonatomic, strong,  readonly) UITableView        *tableView;
@property (nonatomic, strong,  readonly) UIImageView        *logoView;

@property (nonatomic, strong,  readonly) UITextField        *usernameField;
@property (nonatomic, strong,  readonly) UITextField        *passwordField;
@property (nonatomic, strong,  readonly) UITextField        *passwordConfirmField;

@property (nonatomic, strong, readwrite) SPAuthenticator    *authenticator;
@property (nonatomic, assign, readwrite) BOOL               signingIn;

/**
    Performs the current action: Validates the fields, and hits the backend, if needed
 */
- (IBAction)performAction:(id)sender;

@end
