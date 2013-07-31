//
//  SPLoginViewController.h
//  Simperium
//
//  Created by Michael Johnston on 24/11/11.
//  Copyright 2011 Simperium. All rights reserved.
//
//  You can write a subclass of SPLoginViewController and then set loginViewControllerClass on your
//  Simperium instance in order to fully customize the behavior of the authentication UI. 
//
//  Simperium will use the subclass and display your UI automatically.

#import <UIKit/UIKit.h>

@class SPAuthenticationManager;

@interface SPLoginViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIGestureRecognizerDelegate>
{   
    SPAuthenticationManager *authManager;
	BOOL creating;
	UITextField *loginField;
	UITextField *loginPasswordField;
	UITextField *loginPasswordConfirmField;
	UIActivityIndicatorView *progressView;
	UIButton *actionButton, *changeButton;

    UIBarButtonItem *cancelButton;
}

@property (nonatomic, strong) SPAuthenticationManager *authManager;
@property (nonatomic, strong) UITableView* tableView;
//@property (nonatomic) BOOL creating;

@end
