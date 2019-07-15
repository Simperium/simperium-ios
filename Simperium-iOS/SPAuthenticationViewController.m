//
//  SPAuthenticationViewController.m
//  Simperium
//
//  Created by Michael Johnston on 24/11/11.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SPAuthenticationViewController.h"

#import "Simperium.h"
#import "SPAuthenticator.h"
#import "SPAuthenticationButton.h"
#import "SPAuthenticationConfiguration.h"
#import "SPAuthenticationValidator.h"
#import "SPHttpRequest.h"
#import "SPWebViewController.h"

#import "JSONKit+Simperium.h"
#import "NSString+Simperium.h"
#import "UIDevice+Simperium.h"


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

NS_ENUM(NSInteger, SPAuthenticationRows) {
    SPAuthenticationRowsEmail       = 0,
    SPAuthenticationRowsPassword    = 1,
    SPAuthenticationRowsConfirm     = 2
};

static CGFloat const SPAuthenticationFieldPaddingX          = 10.0f;
static CGFloat const SPAuthenticationFieldWidth             = 280.0f;
static CGFloat const SPAuthenticationFieldHeight            = 38.0f;

static CGFloat const SPAuthenticationTableWidthMax          = 400.0f;
static CGFloat const SPAuthenticationCompactPaddingY        = 20.0f;
static CGFloat const SPAuthenticationRegularPaddingY        = 160.0f;


static CGFloat const SPAuthenticationLinkHeight             = 24.0f;
static CGFloat const SPAuthenticationLinkFontSize           = 10.0f;
static CGFloat const SPAuthenticationLinkPadding            = 10.0f;
static UIEdgeInsets const SPAuthenticationLinkTitleInsets   = {3.0f, 0.0f, 0.0f, 0.0f};

static NSString *SPAuthenticationEmailCellIdentifier        = @"EmailCellIdentifier";
static NSString *SPAuthenticationPasswordCellIdentifier     = @"PasswordCellIdentifier";
static NSString *SPAuthenticationConfirmCellIdentifier      = @"ConfirmCellIdentifier";


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPAuthenticationViewController() <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIGestureRecognizerDelegate>

#pragma mark - Public Properties
@property (nonatomic, strong) UITableView               *tableView;
@property (nonatomic, strong) UIImageView               *logoView;

@property (nonatomic, strong) UITextField               *usernameField;
@property (nonatomic, strong) UITextField               *passwordField;
@property (nonatomic, strong) UITextField               *passwordConfirmField;

#pragma mark - Private Properties
@property (nonatomic, strong) SPAuthenticationValidator *validator;

@property (nonatomic, strong) SPAuthenticationButton    *actionButton;
@property (nonatomic, strong) SPAuthenticationButton    *changeButton;
@property (nonatomic, strong) UIButton                  *termsButton;
@property (nonatomic, strong) UIButton                  *forgotPasswordButton;

@property (nonatomic, strong) UIBarButtonItem           *cancelButton;
@property (nonatomic, strong) UIActivityIndicatorView   *progressView;
@property (nonatomic, assign) CGFloat                   keyboardHeight;

@property (nonatomic, assign) BOOL                      editing;

#pragma mark - Layout Constraints
@property (nonatomic, strong) NSLayoutConstraint        *logoTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint        *tableLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint        *tableTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint        *tableCenterConstraint;
@property (nonatomic, strong) NSLayoutConstraint        *tableWidthConstraint;

- (void)earthquake:(UIView*)itemView;
- (void)changeAction:(id)sender;

@end


#pragma mark ====================================================================================
#pragma mark SPAuthenticationViewController
#pragma mark ====================================================================================

@implementation SPAuthenticationViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _shouldSignIn = NO;
    }
    return self;
}

- (void)setShouldSignIn:(BOOL)shouldSignIn {
    _shouldSignIn = shouldSignIn;
    [self refreshButtons];
}

- (void)refreshButtons {
    NSString *actionTitle = _shouldSignIn ?
        NSLocalizedString(@"Sign In", @"Title of button for logging in (must be short)") :
        NSLocalizedString(@"Sign Up", @"Title of button to create a new account (must be short)");
    NSString *changeTitle = _shouldSignIn ?
        NSLocalizedString(@"Sign up", @"A short link to access the account creation screen") :
        NSLocalizedString(@"Sign in", @"A short link to access the account login screen");
    NSString *changeDetailTitle = _shouldSignIn ?
        NSLocalizedString(@"Don't have an account?", @"A short description to access the account creation screen") :
        NSLocalizedString(@"Already have an account?", @"A short description to access the account login screen");

    changeTitle = [[changeTitle stringByAppendingString:@" »"] uppercaseString];
    
    [self.actionButton setTitle:actionTitle forState:UIControlStateNormal];
    [self.changeButton setTitle:changeTitle forState:UIControlStateNormal];
    self.changeButton.detailTitleLabel.text = changeDetailTitle.uppercaseString;

    // Refresh Terms + Forgot Password
    SPAuthenticationConfiguration *configuration = [SPAuthenticationConfiguration sharedInstance];
    BOOL shouldShowTerms = !_shouldSignIn && configuration.termsOfServiceURL;
    BOOL shouldShowForgot = _shouldSignIn && configuration.forgotPasswordURL;
    
    self.termsButton.hidden = !shouldShowTerms;
    self.forgotPasswordButton.hidden = !shouldShowForgot;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.validator = [[SPAuthenticationValidator alloc] init];
    
    SPAuthenticationConfiguration *configuration = [SPAuthenticationConfiguration sharedInstance];
    
    // TODO: Should eventually be paramaterized
    UIColor *whiteColor     = [UIColor colorWithWhite:0.99 alpha:1.0];
    UIColor *blueColor      = [UIColor colorWithRed:66.0 / 255.0 green:137 / 255.0 blue:201 / 255.0 alpha:1.0];
    UIColor *darkBlueColor  = [UIColor colorWithRed:36.0 / 255.0 green:100.0 / 255.0 blue:158.0 / 255.0 alpha:1.0];
    UIColor *lightGreyColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    UIColor *greyColor      = [UIColor colorWithWhite:0.7 alpha:1.0];
    
    self.view.backgroundColor = whiteColor;
    
    // The cancel button will only be visible if there's a navigation controller, which will only happen
    // if authenticationOptional has been set on the Simperium instance.
    NSString *cancelTitle = NSLocalizedString(@"Cancel", @"Cancel button for authentication");
    self.cancelButton = [[UIBarButtonItem alloc] initWithTitle:cancelTitle style:UIBarButtonItemStylePlain target:self action:@selector(cancelAction:)];
    self.navigationItem.rightBarButtonItem = self.cancelButton;

    // TableView
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.backgroundView = nil;
    _tableView.separatorColor = lightGreyColor;
    _tableView.clipsToBounds = NO;
    _tableView.scrollEnabled = NO;
    _tableView.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:_tableView];
    
    if (self.view.bounds.size.height <= 480.0) {
        _tableView.rowHeight = 38.0;
    }
    
    // Terms String
    NSDictionary *termsAttributes = @{
        NSForegroundColorAttributeName: [greyColor colorWithAlphaComponent:0.4]
    };
    
    NSDictionary *termsLinkAttributes = @{
        NSUnderlineStyleAttributeName   : @(NSUnderlineStyleSingle),
        NSForegroundColorAttributeName  : [greyColor colorWithAlphaComponent:0.4]
    };
    
    NSString *termsText = NSLocalizedString(@"By signing up, you agree to our Terms of Service »", @"Terms Button Text");
    NSRange underlineRange = [termsText rangeOfString:@"Terms of Service"];
    NSMutableAttributedString *termsTitle = [[NSMutableAttributedString alloc] initWithString:[termsText uppercaseString] attributes:termsAttributes];
    [termsTitle setAttributes:termsLinkAttributes range:underlineRange];
    
    // Username Field
    NSString *usernameText = @"email@email.com";
    self.usernameField = [self textFieldWithPlaceholder:usernameText secure:NO];
    _usernameField.keyboardType = UIKeyboardTypeEmailAddress;
    
    if (_shouldSignIn && configuration.previousUsernameEnabled && configuration.previousUsernameLogged) {
        // Get previous username, to display as last used username in authentication view
        _usernameField.text = configuration.previousUsernameLogged;
    }
    
    // Password Field
    NSString *passwordText = NSLocalizedString(@"Password", @"Hint displayed in the password field");
    self.passwordField = [self textFieldWithPlaceholder:passwordText secure:YES];

    // Confirm Field
    NSString *confirmText = NSLocalizedString(@"Confirm", @"Hint displayed in the password confirmation field");
    self.passwordConfirmField = [self textFieldWithPlaceholder:confirmText secure:YES];
    _passwordConfirmField.returnKeyType = UIReturnKeyGo;
    
    // Terms Frame
    CGRect termsFrame = CGRectMake(SPAuthenticationLinkPadding,
                                   0.0,
                                   self.tableView.frame.size.width - 2 * SPAuthenticationLinkPadding,
                                   SPAuthenticationLinkHeight);
    
    // Terms Button
    self.termsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_termsButton addTarget:self action:@selector(termsAction:) forControlEvents:UIControlEventTouchUpInside];
    _termsButton.titleEdgeInsets = SPAuthenticationLinkTitleInsets;
    _termsButton.titleLabel.font = [UIFont fontWithName:configuration.mediumFontName size:SPAuthenticationLinkFontSize];
    _termsButton.frame = termsFrame;
    
    _termsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_termsButton setAttributedTitle:termsTitle forState:UIControlStateNormal];
    
    // Forgot Password String
	NSDictionary *forgotPasswordAttributes = @{
        NSForegroundColorAttributeName: [greyColor colorWithAlphaComponent:0.4]
    };
    
	NSString *forgotPasswordText = NSLocalizedString(@"Forgot password? »", @"Forgot password Button Text");
    NSAttributedString *forgotPasswordTitle = [[NSAttributedString alloc] initWithString:forgotPasswordText.uppercaseString
                                                                              attributes:forgotPasswordAttributes];
	
	// Forgot Password Button
    self.forgotPasswordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_forgotPasswordButton addTarget:self action:@selector(forgotPasswordAction:) forControlEvents:UIControlEventTouchUpInside];
    _forgotPasswordButton.titleEdgeInsets = SPAuthenticationLinkTitleInsets;
    _forgotPasswordButton.titleLabel.font = [UIFont fontWithName:configuration.mediumFontName size:SPAuthenticationLinkFontSize];
    _forgotPasswordButton.frame = termsFrame;
    _forgotPasswordButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_forgotPasswordButton setAttributedTitle:forgotPasswordTitle forState:UIControlStateNormal];
    
    // Action
    self.actionButton = [[SPAuthenticationButton alloc] initWithFrame:CGRectMake(0, 30.0, self.view.frame.size.width, 44)];
    [_actionButton addTarget:self action:@selector(performAction:) forControlEvents:UIControlEventTouchUpInside];
    [_actionButton setTitleColor:whiteColor forState:UIControlStateNormal];
    _actionButton.titleLabel.font = [UIFont fontWithName:configuration.regularFontName size:22.0];
    _actionButton.backgroundColor = blueColor;
    _actionButton.backgroundHighlightColor = darkBlueColor;
    _actionButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // Change
    self.changeButton = [[SPAuthenticationButton alloc] initWithFrame:CGRectZero];
    [_changeButton addTarget:self action:@selector(changeAction:) forControlEvents:UIControlEventTouchUpInside];
    [_changeButton setTitleColor:blueColor forState:UIControlStateNormal];
    [_changeButton setTitleColor:greyColor forState:UIControlStateHighlighted];
    _changeButton.detailTitleLabel.textColor = greyColor;
    _changeButton.detailTitleLabel.font = [UIFont fontWithName:configuration.mediumFontName size:12.5];
    _changeButton.titleLabel.font = [UIFont fontWithName:configuration.mediumFontName size:12.5];
    _changeButton.frame = CGRectMake(10.0, 80.0, self.tableView.frame.size.width-20.0, 40.0);
    _changeButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // Progress
    self.progressView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _progressView.frame = CGRectIntegral(CGRectMake(self.actionButton.frame.size.width - 30, (self.actionButton.frame.size.height - 20) / 2.0, 20, 20));
    _progressView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_actionButton addSubview:_progressView];
    
    // Logo
    UIImage *logo = [UIImage imageNamed:[SPAuthenticationConfiguration sharedInstance].logoImageName];
    self.logoView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, logo.size.width, logo.size.height)];
    _logoView.image = logo;
    _logoView.contentMode = UIViewContentModeCenter;
    _logoView.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:_logoView];
    
    // Setup TableView's Footer
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.changeButton.frame.size.height + self.changeButton.frame.origin.y)];
    footerView.contentMode = UIViewContentModeTopLeft;
    footerView.userInteractionEnabled = YES;
    footerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // Attach Footer Views
    [footerView addSubview:_termsButton];
    [footerView addSubview:_forgotPasswordButton];
    [footerView addSubview:_actionButton];
    [footerView addSubview:_changeButton];
    self.tableView.tableFooterView = footerView;
    
    // Setup TableView's GesturesRecognizer
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(endEditingAction:)];
    tapGesture.numberOfTouchesRequired = 1;
    tapGesture.numberOfTapsRequired = 1;
    [self.tableView addGestureRecognizer:tapGesture];
    
    // Refresh Buttons
    [self refreshButtons];

    [self configureViewConstraints];
}

- (void)configureViewConstraints {
    NSLayoutAnchor *topAnchor = self.view.topAnchor;
    if (@available(iOS 11, *)) {
        topAnchor = self.view.safeAreaLayoutGuide.topAnchor;
    }

    NSLayoutConstraint *logoTopConstraint = [_logoView.topAnchor constraintEqualToAnchor:topAnchor];
    NSLayoutConstraint *tableWidthConstraint = [_tableView.widthAnchor constraintEqualToConstant:SPAuthenticationTableWidthMax];
    NSLayoutConstraint *tableLeadingConstraint = [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor];
    NSLayoutConstraint *tableCenterConstraint = [_tableView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor];
    NSLayoutConstraint *tableTrailingConstraint = [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor];

    tableWidthConstraint.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        logoTopConstraint,
        [_logoView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_tableView.topAnchor constraintEqualToAnchor:_logoView.bottomAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        tableLeadingConstraint,
        tableCenterConstraint,
        tableTrailingConstraint,
    ]];

    self.logoTopConstraint = logoTopConstraint;
    self.tableLeadingConstraint = tableLeadingConstraint;
    self.tableCenterConstraint = tableCenterConstraint;
    self.tableTrailingConstraint = tableTrailingConstraint;
    self.tableWidthConstraint = tableWidthConstraint;
}

- (void)updateViewConstraints {
    BOOL isRegulardByRegular = [self isRegulardByRegularSizeClass];

    self.logoTopConstraint.constant = [self logoPaddingTop];
    self.tableLeadingConstraint.active = !isRegulardByRegular;
    self.tableTrailingConstraint.active = !isRegulardByRegular;
    self.tableCenterConstraint.active = isRegulardByRegular;
    self.tableWidthConstraint.active = isRegulardByRegular;

    [super updateViewConstraints];
}

- (CGFloat)topInset {
    CGFloat navigationBarHeight = self.navigationController.navigationBar.frame.size.height + self.navigationController.navigationBar.frame.origin.y;
    return navigationBarHeight > 0 ? navigationBarHeight : 20.0; // 20.0 refers to the status bar height
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self.view setNeedsUpdateConstraints];
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    [self.view setNeedsUpdateConstraints];
}

- (BOOL)shouldAutorotate {
    return !_editing;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return [UIDevice sp_isPad] ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Register for keyboard notifications
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // un-register for keyboard notifications
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver: self name:UIKeyboardWillHideNotification object:nil];
    [nc removeObserver: self name:UIKeyboardWillShowNotification object:nil];
}


#pragma mark - Layout Helpers

- (CGFloat)logoPaddingTop {
    return [self isRegulardByRegularSizeClass] ? SPAuthenticationRegularPaddingY : SPAuthenticationCompactPaddingY;
}

- (BOOL)isRegulardByRegularSizeClass {
    return self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular &&
            self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular;
}


#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
    
    CGRect keyboardFrame = [(NSValue *)notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSNumber* duration = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
    
    _editing = YES;
    _keyboardHeight = MIN(keyboardFrame.size.height, keyboardFrame.size.width);
    
    [self positionTableViewWithDuration:duration.floatValue];
}

- (void)keyboardWillHide:(NSNotification *)notification {

    NSNumber* duration = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
    
    _editing = NO;
    _keyboardHeight = 0;

    [self positionTableViewWithDuration:duration.floatValue];
}

- (void)positionTableViewWithDuration:(CGFloat)duration {
    CGRect newFrame = self.view.bounds;
    if (_keyboardHeight > 0) {
        CGFloat maxHeight = newFrame.size.height - _keyboardHeight - self.topInset;
        CGFloat tableViewHeight = [self.tableView tableFooterView].frame.origin.y + [self.tableView tableFooterView].frame.size.height;
        CGFloat tableViewTopPadding = [self.tableView convertRect:[self.tableView cellForRowAtIndexPath:[self emailIndexPath]].frame fromView:self.tableView].origin.y;
        
        newFrame.origin.y = MAX((maxHeight - tableViewHeight - tableViewTopPadding) / 2.0 + self.topInset, self.topInset - tableViewTopPadding);
        newFrame.size.height = maxHeight  + tableViewTopPadding;

        self.tableView.scrollEnabled = YES;
    } else {
        newFrame.origin.y = _logoView.frame.origin.y + _logoView.frame.size.height;
        newFrame.size.height = self.view.frame.size.height -  newFrame.origin.y;
        self.tableView.scrollEnabled = NO;
    }
    
    newFrame.size.width = self.tableView.frame.size.width;
    newFrame.origin.x = self.tableView.frame.origin.x;

    if (!(_keyboardHeight > 0)) {
        self.logoView.hidden = NO;
    }

    self.tableView.tableHeaderView.alpha = _keyboardHeight > 0 ? 1.0 : 0.0;
    
    [UIView animateWithDuration:duration
                     animations:^{
                         self.tableView.frame = newFrame;
                         self.logoView.alpha = _keyboardHeight > 0 ? 0.0 : 1.0;
                     }
                    completion:^(BOOL finished) {
                         self.logoView.hidden = (_keyboardHeight > 0);
                     }];
}


#pragma mark - Validation

- (BOOL)validateUsername {
    if (![self.validator validateUsername:[self.usernameField.text sp_trim]]) {
        NSString *errorText = NSLocalizedString(@"Your email address is not valid.", @"Message displayed when email address is invalid");
        [self.actionButton showErrorMessage:errorText];
        [self earthquake:[self.tableView cellForRowAtIndexPath:[self emailIndexPath]]];
        return NO;
    }
    
    return YES;
}

- (BOOL)validatePassword {
    if (![self.validator validatePasswordSecurity:self.passwordField.text]) {
        NSString *errorText = NSLocalizedString(@"Password must contain at least 4 characters.", @"Message displayed when password is invalid");
        [self.actionButton showErrorMessage:errorText];
        [self earthquake:[self.tableView cellForRowAtIndexPath:[self passwordIndexPath]]];
        return NO;
    }
        
    return YES;
}

- (BOOL)validateData {
    if (![self validateUsername]) {
        return NO;
    }
    
    return [self validatePassword];
}

- (BOOL)validatePasswordConfirmation {
    if ([self.passwordField.text compare: self.passwordConfirmField.text] != NSOrderedSame) {
        [self earthquake: self.passwordField];
        [self earthquake: self.passwordConfirmField];
        return NO;
    }
    
    return YES;
}


#pragma mark - Login

- (void)performLogin {
    self.view.userInteractionEnabled = NO;
    [self.view endEditing:YES];
    
    [self.progressView setHidden:NO];
    [self.progressView startAnimating];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

    [self.authenticator authenticateWithUsername:[self.usernameField.text sp_trim]
                                        password:self.passwordField.text
                                         success:^{
                                            [self.progressView setHidden:YES];
                                            [self.progressView stopAnimating];
                                            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                                        }
                                        failure: ^(int responseCode, NSString *responseString){
                                            self.view.userInteractionEnabled = YES;

                                            [self.progressView setHidden:YES];
                                            [self.progressView stopAnimating];
                                            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                         
                                            NSString* loginError = [self loginErrorForCode:responseCode];
                                            [self.actionButton showErrorMessage:loginError];
                        
                                            [self earthquake:[self.tableView cellForRowAtIndexPath:[self emailIndexPath]]];
                                            [self earthquake:[self.tableView cellForRowAtIndexPath:[self passwordIndexPath]]];
                                        }
     ];
}

- (NSString*)loginErrorForCode:(NSUInteger)responseCode {
    switch (responseCode) {
        case 401:
            // Bad email or password
            return NSLocalizedString(@"Could not login with the provided email address and password.", @"Message displayed when login fails");
        default:
            // General network problem
            return NSLocalizedString(@"We're having problems. Please try again soon.", @"Generic error");
    }
}


#pragma mark - Creation

- (void)restoreCreationSettings {
    self.actionButton.enabled = YES;
    self.changeButton.enabled = YES;
    self.cancelButton.enabled = YES;
    [self.progressView setHidden: YES];
    [self.progressView stopAnimating];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (void)performCreation {
    self.actionButton.enabled = NO;
    self.changeButton.enabled = NO;
    self.cancelButton.enabled = NO;

    [self.usernameField resignFirstResponder];
    [self.passwordField resignFirstResponder];
    [self.passwordConfirmField resignFirstResponder];
    
    // Try to login and sync after entering password?
    [self.progressView setHidden: NO];
    [self.progressView startAnimating];
    [self.authenticator createWithUsername:[self.usernameField.text sp_trim]
                                password:self.passwordField.text
                                  success:^{
                                      [self.progressView setHidden: YES];
                                      [self.progressView stopAnimating];
                                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                                }
                                   failure:^(int responseCode, NSString *responseString){
                                       [self restoreCreationSettings];

                                       NSString *message = [self signupErrorForCode:responseCode];
                                       [self.actionButton showErrorMessage:message];

                                       [self earthquake:[self.tableView cellForRowAtIndexPath:[self emailIndexPath]]];
                                       [self earthquake:[self.tableView cellForRowAtIndexPath:[self passwordIndexPath]]];
                                       [self earthquake:[self.tableView cellForRowAtIndexPath:[self confirmIndexPath]]];
                                }
     ];
}

- (NSString*)signupErrorForCode:(NSUInteger)responseCode {
    switch (responseCode) {
        case 409:
            // User already exists
            return NSLocalizedString(@"That email is already being used", @"Error when address is in use");
        case 401:
            // Bad email or password
            return NSLocalizedString(@"Could not create an account with the provided email address and password.", @"Error for bad email or password");
        default:
            // General network problem
            return NSLocalizedString(@"We're having problems. Please try again soon.", @"Generic error");
    }
}


#pragma mark - Actions

- (IBAction)termsAction:(id)sender {
    NSString *termsOfServiceURL = [[SPAuthenticationConfiguration sharedInstance] termsOfServiceURL];
    [self showWebviewWithURL:termsOfServiceURL];
}

- (IBAction)forgotPasswordAction:(id)sender {
    SPAuthenticationConfiguration *configuration = [SPAuthenticationConfiguration sharedInstance];
    NSString *forgotPasswordURL = configuration.forgotPasswordURL;
    
    // Post the email already entered in the Username Field. This allows us to prefill the Forgot Password Form
    NSString *username = [self.usernameField.text sp_trim];
    if (username.length) {
        NSString *parameters = [NSString stringWithFormat:@"?email=%@", username];
        forgotPasswordURL = [forgotPasswordURL stringByAppendingString:parameters];
    }
    
    [self showWebviewWithURL:forgotPasswordURL];
}

- (IBAction)changeAction:(id)sender {
    _shouldSignIn = !_shouldSignIn;
    NSArray *indexPaths = @[ [self confirmIndexPath] ];
    if (_shouldSignIn) {
        [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
    } else {
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
    }
    
    [self.usernameField becomeFirstResponder];

    [self setShouldSignIn:_shouldSignIn];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self positionTableViewWithDuration:0.3];
    });
}

- (IBAction)performAction:(id)sender {
    if ([self validateData]) {
        if (!_shouldSignIn && self.passwordConfirmField.text.length > 0) {
            if ([self validatePasswordConfirmation]) {
                [self performCreation];
            }
        } else {
            [self performLogin];
        }
    }
}

- (IBAction)cancelAction:(id)sender {
    [self.authenticator cancel];
}

- (IBAction)endEditingAction:(id)sender {
    [self.view endEditing:YES];
}


#pragma mark - Text Field

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    [self.actionButton clearErrorMessage];
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    if (theTextField == self.usernameField) {
        if (![self validateUsername]) {
            return NO;
        }
        
        // Advance to next field and don't dismiss keyboard
        [self.passwordField becomeFirstResponder];
        return NO;
    } else if (theTextField == self.passwordField) {
        if ([self validatePassword]) {
            if (_shouldSignIn) {
                [self performLogin];
            } else {
                // Advance to next field and don't dismiss keyboard
                [self.passwordConfirmField becomeFirstResponder];
                return NO;
            }
        }
    } else {
        if (!_shouldSignIn && [self validatePasswordConfirmation] && [self validateData]) {
            [self performCreation];
        }
    }
    
    return YES;
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder secure:(BOOL)secure {
    CGRect textFieldFrame = CGRectMake(0.0f, 0.0f, SPAuthenticationFieldWidth, SPAuthenticationFieldHeight);
    UITextField *newTextField = [[UITextField alloc] initWithFrame:textFieldFrame];
    newTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    newTextField.clearsOnBeginEditing = NO;
    newTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    newTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    newTextField.secureTextEntry = secure;
    newTextField.font = [UIFont fontWithName:[SPAuthenticationConfiguration sharedInstance].regularFontName size:22.0];
    newTextField.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    newTextField.delegate = self;
    newTextField.returnKeyType = UIReturnKeyNext;
    newTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    newTextField.placeholder = placeholder;
 
    return newTextField;
}

- (void)positionTextField:(UITextField *)textField inCell:(UITableViewCell *)cell {
    textField.frame = CGRectIntegral(CGRectMake(SPAuthenticationFieldPaddingX,
                                                (cell.bounds.size.height - SPAuthenticationFieldHeight) * 0.5f,
                                                cell.bounds.size.width - 2.0f * SPAuthenticationFieldPaddingX,
                                                SPAuthenticationFieldHeight));
    
}


#pragma mark - Table Data Source Methods

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 4.0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
    return _shouldSignIn ? (SPAuthenticationRowsPassword + 1) : (SPAuthenticationRowsConfirm + 1);
}

- (UITableViewCell *)tableView:(UITableView *)tView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = nil;
    if (indexPath.row == SPAuthenticationRowsEmail) {
        cell = [tView dequeueReusableCellWithIdentifier:SPAuthenticationEmailCellIdentifier];
        // Email
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SPAuthenticationEmailCellIdentifier];
            
            [self positionTextField:_usernameField inCell:cell];
            [cell.contentView addSubview:_usernameField];
        }
    } else if (indexPath.row == SPAuthenticationRowsPassword) {
        cell = [tView dequeueReusableCellWithIdentifier:SPAuthenticationPasswordCellIdentifier];
        // Password
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SPAuthenticationPasswordCellIdentifier];
            
            [self positionTextField:_passwordField inCell:cell];
            [cell.contentView addSubview:_passwordField];
        }
        
        self.passwordField.returnKeyType = _shouldSignIn ? UIReturnKeyGo : UIReturnKeyNext;
    } else {
        cell = [tView dequeueReusableCellWithIdentifier:SPAuthenticationConfirmCellIdentifier];
        // Password Confirmation
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SPAuthenticationConfirmCellIdentifier];
            
            [self positionTextField:_passwordConfirmField inCell:cell];
            [cell.contentView addSubview:_passwordConfirmField];
        }
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1.0];
    
    return cell;
}


#pragma mark - Helpers

- (void)earthquake:(UIView*)itemView {
    // From http://stackoverflow.com/a/1827373/1379066
    CGFloat t = 2.0;
    
    CGAffineTransform leftQuake  = CGAffineTransformTranslate(CGAffineTransformIdentity, t, 0);
    CGAffineTransform rightQuake = CGAffineTransformTranslate(CGAffineTransformIdentity, -t, 0);
    
    itemView.transform = leftQuake;  // starting point
    
    [UIView beginAnimations:@"earthquake" context:(__bridge void *)(itemView)];
    [UIView setAnimationRepeatAutoreverses:YES]; // important
    [UIView setAnimationRepeatCount:5];
    [UIView setAnimationDuration:0.07];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(earthquakeEnded:finished:context:)];
    
    itemView.transform = rightQuake; // end here & auto-reverse
    
    [UIView commitAnimations];
}

- (void)earthquakeEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    if ([finished boolValue]) {
        UIView* item = (__bridge UIView *)context;
        item.transform = CGAffineTransformIdentity;
    }
}

- (NSIndexPath *)emailIndexPath {
    return [NSIndexPath indexPathForItem:SPAuthenticationRowsEmail inSection:0];
}

- (NSIndexPath *)passwordIndexPath {
    return [NSIndexPath indexPathForItem:SPAuthenticationRowsPassword inSection:0];
}

- (NSIndexPath *)confirmIndexPath {
    return [NSIndexPath indexPathForItem:SPAuthenticationRowsConfirm inSection:0];
}

- (void)showWebviewWithURL:(NSString *)targetURL {
    
    NSParameterAssert(targetURL);
    
    SPWebViewController *vc                 = [[SPWebViewController alloc] initWithURL:targetURL];
    UINavigationController *navController   = [[UINavigationController alloc] initWithRootViewController:vc];
    
    if (self.navigationController) {
        [self.navigationController presentViewController:navController animated:YES completion:nil];
    } else {
        [self presentViewController:navController animated:YES completion:nil];
    }
}

@end
