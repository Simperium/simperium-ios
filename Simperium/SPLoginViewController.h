//
//  SPLoginViewController.h
//  Simperium
//
//  Created by Michael Johnston on 24/11/11.
//  Copyright 2011 Simperium. All rights reserved.
//
//  You can write a subclass of SPLoginViewController and then set loginViewControllerClass on your
//  Simperium instance in order to fully customize the behavior of the authentication UI. You can use
//  your own .xib as well, but currently it must be named LoginView.xib (or LoginView-iPad.xib).
//
//  Simperium will use the subclass and display your UI automatically.

#import <UIKit/UIKit.h>

@class SPAuthenticationManager;

@interface SPLoginViewController : UIViewController<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
{   
    SPAuthenticationManager *authManager;
	BOOL creating;
	IBOutlet UITextField *loginField;
	IBOutlet UITextField *loginPasswordField;
	IBOutlet UITextField *loginPasswordConfirmField;
	IBOutlet UIActivityIndicatorView *progressView;
	IBOutlet UINavigationBar *navbar;
	UIButton *actionButton, *changeButton;
	IBOutlet UIView *welcomeView;
	IBOutlet UITableView *tableView;
	IBOutlet UILabel *welcomeLabel;
	IBOutlet UIButton *createButton;
	IBOutlet UIButton *loginButton;
    UIBarButtonItem *cancelButton;
}

@property (nonatomic, strong) SPAuthenticationManager *authManager;
@property (nonatomic, strong) UITableView* tableView;
@property (nonatomic) BOOL creating;

@end
