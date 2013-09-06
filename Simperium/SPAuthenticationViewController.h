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
@class SPAuthenticationButton;
@class SPAuthenticationValidator;

@interface SPAuthenticationViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIGestureRecognizerDelegate>
{   
    SPAuthenticator *authenticator;
    SPAuthenticationValidator *validator;
	BOOL creating;
	UITextField *usernameField;
	UITextField *passwordField;
	UITextField *passwordConfirmField;
	UIActivityIndicatorView *progressView;
	SPAuthenticationButton *actionButton;
    UIButton *termsButton;
    UIButton *changeButton;

    BOOL editing;
    
    UIBarButtonItem *cancelButton;
}

@property (nonatomic, strong) SPAuthenticator *authenticator;
@property (nonatomic, strong) UITableView* tableView;
@property (nonatomic, strong) UIImageView *logoView;

@end
