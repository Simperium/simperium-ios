//
//  SPAutehnticationViewController.m
//  Simperium
//
//  Created by Michael Johnston on 24/11/11.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SPAuthenticationViewController.h"
#import "SPAuthenticator.h"
#import <Simperium/Simperium.h>
#import "ASIFormDataRequest.h"
#import "JSONKit.h"
#import "SPAuthenticationButton.h"
#import "SPAuthenticationConfiguration.h"

@interface SPAuthenticationViewController()

@property (nonatomic) CGFloat keyboardHeight;

-(void)earthquake:(UIView*)itemView;
-(void)changeAction:(id)sender;
@end

@implementation SPAuthenticationViewController
@synthesize authenticator;


- (void)setCreating:(BOOL)bCreating {
	creating = bCreating;
	
	NSString *actionTitle = creating ?
		NSLocalizedString(@"Sign Up", @"Title of button to create a new account (must be short)") :
		NSLocalizedString(@"Sign In", @"Title of button for logging in (must be short)");
	NSString *changeTitle = creating ?
		NSLocalizedString(@"Already have an account? Sign in", @"A short link to access the account login screen") :
		NSLocalizedString(@"Don't have an account? Sign up", @"A short link to access the account creation screen");
    
	[actionButton setTitle: actionTitle forState:UIControlStateNormal];
	[changeButton setTitle: changeTitle.uppercaseString forState:UIControlStateNormal];
    
}

- (void)viewDidLoad {
    // Should eventually be paramaterized
    UIColor *whiteColor = [UIColor colorWithWhite:0.99 alpha:1.0];
    UIColor *blueColor = [UIColor colorWithRed:66.0 / 255.0 green:137 / 255.0 blue:201 / 255.0 alpha:1.0];
    UIColor *darkBlueColor = [UIColor colorWithRed:36.0 / 255.0 green:100.0 / 255.0 blue:158.0 / 255.0 alpha:1.0];
    UIColor *lightGreyColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    UIColor *greyColor = [UIColor colorWithWhite:0.7 alpha:1.0];    
    
    self.view.backgroundColor = whiteColor;
	
    // The cancel button will only be visible if there's a navigation controller, which will only happen
    // if authenticationOptional has been set on the Simperium instance.
    cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                    style:UIBarButtonItemStyleBordered
                                                   target:self
                                                   action:@selector(cancelAction:)];
    self.navigationItem.rightBarButtonItem = cancelButton;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    self.tableView.separatorColor = lightGreyColor;
    self.tableView.clipsToBounds = NO;
    [self.view addSubview:self.tableView];
	
	actionButton = [[SPAuthenticationButton alloc] initWithFrame:CGRectMake(0, 0.0, self.view.frame.size.width, 44)];
	[actionButton addTarget:self
                     action:@selector(goAction:)
           forControlEvents:UIControlEventTouchUpInside];
    [actionButton setTitleColor:whiteColor forState:UIControlStateNormal];
    actionButton.titleLabel.font = [UIFont fontWithName:@"SourceSansPro-Regular" size:22.0];
    
    [actionButton setBackgroundColor:blueColor];
    [actionButton setBackgroundHighlightColor:darkBlueColor];
	actionButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	changeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[changeButton addTarget:self
                     action:@selector(changeAction:)
           forControlEvents:UIControlEventTouchUpInside];
    [changeButton setTitleColor:greyColor forState:UIControlStateNormal];
    [changeButton setTitleColor:blueColor forState:UIControlStateHighlighted];
    changeButton.titleLabel.font = [UIFont fontWithName:@"SourceSansPro-Semibold" size:12.0];
    changeButton.frame= CGRectMake(10, 50, self.tableView.frame.size.width-20, 40);
	changeButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	progressView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	progressView.frame = CGRectMake(actionButton.frame.size.width - 30, (actionButton.frame.size.height - 20) / 2.0, 20, 20);
    progressView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[actionButton addSubview:progressView];
    
    UIImage *logo = [UIImage imageNamed:@"logo_login"];
    _logoView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, logo.size.width, logo.size.height)];
    _logoView.image = logo;
    _logoView.contentMode = UIViewContentModeCenter;
    [self.view addSubview:_logoView];
    
	UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, changeButton.frame.size.height + changeButton.frame.origin.y)];
	footerView.contentMode = UIViewContentModeTopLeft;
	[footerView setUserInteractionEnabled:YES];
	[footerView addSubview:actionButton];
	[footerView addSubview:changeButton];
	footerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = footerView;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(endEditingAction:)];
    tapGesture.numberOfTouchesRequired = 1;
    tapGesture.numberOfTapsRequired = 1;
    [self.tableView addGestureRecognizer:tapGesture];
    
	self.creating = YES;
    
    // layout views
    [self layoutViewsForInterfaceOrientation:self.interfaceOrientation];
}

- (CGFloat)topInset {
    CGFloat navigationBarHeight = self.navigationController.navigationBar.frame.size.height + self.navigationController.navigationBar.frame.origin.y;
    
    return navigationBarHeight > 0 ? navigationBarHeight : 20.0; // 20.0 refers to the status bar height
}

- (void)layoutViewsForInterfaceOrientation:(UIInterfaceOrientation)orientation {
    CGFloat viewWidth = UIInterfaceOrientationIsPortrait(orientation) ? MIN(self.view.frame.size.width, self.view.frame.size.height) :  MAX(self.view.frame.size.width, self.view.frame.size.height);
    
    _logoView.frame = CGRectMake((viewWidth - _logoView.frame.size.width) / 2.0,
                                 (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 180.0 : 20.0 + self.topInset,
                                 _logoView.frame.size.width,
                                 _logoView.frame.size.height);
    
    CGFloat tableViewYOrigin = _logoView.frame.origin.y + _logoView.frame.size.height;
    CGFloat tableViewWidth = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 400 : viewWidth;
    
    _tableView.frame = CGRectMake((viewWidth - tableViewWidth) / 2.0,
                                  tableViewYOrigin,
                                  tableViewWidth,
                                  self.view.frame.size.height - tableViewYOrigin);
    
    [self.view sendSubviewToBack:_logoView];
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
    [self layoutViewsForInterfaceOrientation:toInterfaceOrientation];
}

- (BOOL)shouldAutorotate {
    return !editing;
}


- (NSUInteger)supportedInterfaceOrientations {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        return UIInterfaceOrientationMaskPortrait;
    
    return UIInterfaceOrientationMaskAll;
}


- (void)viewWillAppear:(BOOL)animated {
    self.tableView.scrollEnabled = NO;
    
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		self.tableView.scrollEnabled = NO;
        [self.tableView setBackgroundView:nil];
	}

    // register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    // un-register for keyboard notifications
	[[NSNotificationCenter defaultCenter] removeObserver: self name:UIKeyboardWillHideNotification object:nil];	
	[[NSNotificationCenter defaultCenter] removeObserver: self name:UIKeyboardWillShowNotification object:nil];	
}

#pragma mark Keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
    editing = YES;
    
    CGRect keyboardFrame = [(NSValue *)[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _keyboardHeight = MIN(keyboardFrame.size.height, keyboardFrame.size.width);
    CGFloat duration = [(NSNumber *)[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    
    [self positionTableViewWithDuration:duration];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    editing = NO;
    
    CGFloat duration = [(NSNumber *)[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    
    _keyboardHeight = 0;
    
    [self positionTableViewWithDuration:duration];
}

- (void)positionTableViewWithDuration:(CGFloat)duration {
    CGRect newFrame = self.view.bounds;
    
    if (_keyboardHeight > 0) {
        CGFloat maxHeight = newFrame.size.height - _keyboardHeight - self.topInset;
        CGFloat tableViewHeight = [self.tableView tableFooterView].frame.origin.y + [self.tableView tableFooterView].frame.size.height;
        CGFloat tableViewTopPadding = [self.tableView convertRect:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]].frame fromView:self.tableView].origin.y;
        
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
                     } completion:^(BOOL finished) {
                         self.logoView.hidden = (_keyboardHeight > 0);
                     }];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)	
		return YES;
	
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark Validation
- (BOOL)validateEmailWithAlerts:(BOOL)alert {
	if (loginField.text.length == 0)
		return NO;
    NSString *emailRegEx = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
	NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegEx];
	if (loginField.text != nil && [emailTest evaluateWithObject:loginField.text] == NO) {
		if (alert) {
            [actionButton showErrorMessage:NSLocalizedString(@"Your email address is not valid.", @"Message displayed when email address is invalid")];
            
            [self earthquake:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]];
		}
		return NO;		
	}	
	return YES;
}

- (BOOL)validatePasswordWithAlerts:(BOOL)alert {
	if (loginPasswordField.text == nil || [loginPasswordField.text length] < 4)
	{
		if (alert) {
			// Bad password
//			NSString *title = NSLocalizedString(@"Invalid password", @"Title of a dialog displayed when password is invalid");
//			NSString *message = NSLocalizedString(@"Password must contain at least 4 characters.", @"Message displayed when password is invalid");
//			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
//                                                            message:message
//														   delegate:self
//                                                  cancelButtonTitle:@"OK"
//                                                  otherButtonTitles: nil];
//			[alert show];
            
            [actionButton showErrorMessage:NSLocalizedString(@"Password must contain at least 4 characters.", @"Message displayed when password is invalid")];
            [self earthquake:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:1 inSection:0]]];
            
		}
		return NO;
	}
	return YES;
}

-(BOOL)validateDataWithAlerts:(BOOL)alert
{
	if (![self validateEmailWithAlerts:alert])
		return NO;
	
	return [self validatePasswordWithAlerts:alert];
}

-(BOOL)validatePasswordConfirmation
{
	if ([loginPasswordField.text compare: loginPasswordConfirmField.text] != NSOrderedSame) {
		[self earthquake: loginPasswordField];
		[self earthquake: loginPasswordConfirmField];
		return NO;
	}
	return YES;
}

#pragma mark Login

-(void)performLogin
{	
	actionButton.enabled = NO;
	changeButton.enabled = NO;
    cancelButton.enabled = NO;

	[loginField resignFirstResponder];
	[loginPasswordField resignFirstResponder];
	[progressView setHidden: NO];
	[progressView startAnimating];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

    [self.authenticator authenticateWithUsername:loginField.text password:loginPasswordField.text
                     success:^{
                         [progressView setHidden: YES];
                         [progressView stopAnimating];	
                         [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                         //[self closeLoginScreenAnimated:YES];
                     }
                     failure: ^(int responseCode, NSString *responseString){
                         
                         actionButton.enabled = YES;
                         changeButton.enabled = YES;
                         cancelButton.enabled = YES;

                         [progressView setHidden: YES];
                         [progressView stopAnimating];	
                         [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                           
//                         NSString *title = NSLocalizedString(@"Login failed", @"Title of a dialog displayed when login fails");
//                         NSString *message = NSLocalizedString(@"Could not login with the provided email address and password.", @"Message displayed when login fails");
//                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message
//                                                                          delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
//                         [alert show];
                         
                         [actionButton showErrorMessage:NSLocalizedString(@"Could not login with the provided email address and password.", @"Message displayed when login fails")];
                         [self earthquake:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]];
                         [self earthquake:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:1 inSection:0]]];
                       }
     ];
}

#pragma mark Creatio

-(void)restoreCreationSettings
{
	actionButton.enabled = YES;
	changeButton.enabled = YES;
    cancelButton.enabled = YES;
	[progressView setHidden: YES];
	[progressView stopAnimating];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	CFPreferencesSetAppValue(CFSTR("email"), @"", kCFPreferencesCurrentApplication);
	CFPreferencesSetAppValue(CFSTR("password"), @"", kCFPreferencesCurrentApplication);
	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
}

-(void)performCreation
{
	actionButton.enabled = NO;
	changeButton.enabled = NO;
    cancelButton.enabled = NO;

	[loginField resignFirstResponder];
	[loginPasswordField resignFirstResponder];
	[loginPasswordConfirmField resignFirstResponder];
	CFPreferencesSetAppValue(CFSTR("email"), (__bridge CFPropertyListRef)(loginField.text), kCFPreferencesCurrentApplication);
	CFPreferencesSetAppValue(CFSTR("password"), (__bridge CFPropertyListRef)(loginPasswordField.text), kCFPreferencesCurrentApplication);
	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
	
	// Try to login and sync after entering password?
	[progressView setHidden: NO];
	[progressView startAnimating];
    [authenticator createWithUsername:loginField.text password:loginPasswordField.text
                success:^{	
                    [progressView setHidden: YES];
                    [progressView stopAnimating];
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];	
                   
                    //[appDelegate closeLoginScreenAnimated:YES];	
                   
#ifdef TESTFLIGHT
                   [TestFlight passCheckpoint:@"Account created"];
#endif
                }
                failure:^(int responseCode, NSString *responseString){
                    [self restoreCreationSettings];
//                    NSString *title = NSLocalizedString(@"Account creation failed",
//                                                        @"The title for a dialog that notifies you when account creation fails");
//                    NSString *message = NSLocalizedString(@"Could not create an account with the provided email address and password.", @"An error message");
//                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message: message
//                                                                   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
//                    [alert show];
                    
                    [actionButton showErrorMessage:NSLocalizedString(@"Could not create an account with the provided email address and password.", @"An error message")];
                    
                    [self earthquake:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]];
                    [self earthquake:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:1 inSection:0]]];
                    [self earthquake:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:2 inSection:0]]];
                }
     ];
}

-(void)failedDueToNetwork:(ASIHTTPRequest *)request
{
	[self restoreCreationSettings];
//	NSString *title = NSLocalizedString(@"No connection",
//										@"The title for a dialog that is displayed when there's a connection problem");
	NSString *message = NSLocalizedString(@"There's a problem with the connection.  Please try again later.",
										  @"Details for a dialog that is displayed when there's a connection problem");
//	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message
//												   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
//	[alert show];
    
    [actionButton showErrorMessage:message];
    
    [self earthquake:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]];
    [self earthquake:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:1 inSection:0]]];
}

#pragma mark Actions

-(void)changeAction:(id)sender
{
	creating = !creating;
    NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:2 inSection:0]];
    if (creating)
        [self.tableView insertRowsAtIndexPaths: indexPaths withRowAnimation:UITableViewRowAnimationTop];
    else
        [self.tableView deleteRowsAtIndexPaths: indexPaths withRowAnimation:UITableViewRowAnimationTop];
	[loginField becomeFirstResponder];
    
    [self setCreating:creating];
    [self positionTableViewWithDuration:0.3];
    
}

-(void)goAction:(id)sender
{
	if ([self validateDataWithAlerts:YES]) {
		if (creating) {
			if ([self validatePasswordConfirmation])
				[self performCreation];
		} else
			[self performLogin];
	}
}

-(void)cancelAction:(id)sender
{
    [authenticator cancel];
}

- (void)endEditingAction:(id)sender {
    
    [self.view endEditing:YES];
    
}

#pragma mark Text Field

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    [actionButton clearErrorMessage];
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
	if (theTextField == loginField)
	{
		if (![self validateEmailWithAlerts:YES]) {
			return NO;
		}
		
		// Advance to next field and don't dismiss keyboard
		[loginPasswordField becomeFirstResponder];
		return NO;
	}
	else if(theTextField == loginPasswordField)
	{
		if ([self validatePasswordWithAlerts:YES]) {
			if (creating) {
				// Advance to next field and don't dismiss keyboard
				[loginPasswordConfirmField becomeFirstResponder];
				return NO;
			} else
				[self performLogin];
		}
	}
	else
	{
		if (creating && [self validatePasswordConfirmation] && [self validateDataWithAlerts:YES])
			[self performCreation];
	}
	
    return YES;
}


- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder secure:(BOOL)secure {
    
    UITextField *newTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 280, 25)];
    newTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    newTextField.clearsOnBeginEditing = NO;
    newTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    newTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    newTextField.secureTextEntry = secure;
    newTextField.font = [UIFont fontWithName:@"SourceSansPro-Regular" size:22.0];
    newTextField.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    [newTextField setDelegate:self];
    newTextField.returnKeyType = UIReturnKeyNext;
    newTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    newTextField.placeholder = placeholder;
 
    return newTextField;
}

- (void)positionTextField:(UITextField *)textField inCell:(UITableViewCell *)cell {

    CGFloat sidePadding = 10.0;
    CGFloat fieldHeight = textField.font.lineHeight;
    textField.frame = CGRectMake(sidePadding,
                                 (cell.bounds.size.height - fieldHeight) / 2.0,
                                 cell.bounds.size.width - 2 * sidePadding,
                                 fieldHeight);
}

#pragma mark Table Data Source Methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return creating ? 3 : 2;
}


- (UITableViewCell *)tableView:(UITableView *)tView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *EmailCellIdentifier = @"EmailCellIdentifier";
	static NSString *PasswordCellIdentifier = @"PasswordCellIdentifier";
	static NSString *ConfirmCellIdentifier = @"ConfirmCellIdentifier";

	UITableViewCell *cell;
	if (indexPath.row == 0) {
		cell = [tView dequeueReusableCellWithIdentifier:EmailCellIdentifier];
		// Email
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:EmailCellIdentifier];
            
			loginField = [self textFieldWithPlaceholder:@"email@email.com"
                                                 secure:NO];
            loginField.keyboardType = UIKeyboardTypeEmailAddress;
            [self positionTextField:loginField inCell:cell];
            [cell.contentView addSubview:loginField];
		}
	} else if (indexPath.row == 1) {
		cell = [tView dequeueReusableCellWithIdentifier:PasswordCellIdentifier];		
		// Password
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PasswordCellIdentifier];
			
			loginPasswordField = [self textFieldWithPlaceholder:NSLocalizedString(@"Password", @"Hint displayed in the password field")
                                                         secure:YES];
            
            [self positionTextField:loginPasswordField inCell:cell];
            [cell.contentView addSubview:loginPasswordField];
		}
		
		loginPasswordField.returnKeyType = creating ? UIReturnKeyNext : UIReturnKeyGo;
	} else {
		cell = [tView dequeueReusableCellWithIdentifier:ConfirmCellIdentifier];		
		// Password
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ConfirmCellIdentifier];
			
			loginPasswordConfirmField = [self textFieldWithPlaceholder:NSLocalizedString(@"Confirm", @"Hint displayed in the password confirmation field") secure:YES];
			loginPasswordConfirmField.returnKeyType = UIReturnKeyGo;
			
            [self positionTextField:loginPasswordConfirmField inCell:cell];
            [cell.contentView addSubview:loginPasswordConfirmField];
		}
	}
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1.0];
	return cell;
}

#pragma mark Helpers
- (void)earthquake:(UIView*)itemView
{
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

- (void)earthquakeEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context 
{
    if ([finished boolValue]) 
    {
        UIView* item = (__bridge UIView *)context;
        item.transform = CGAffineTransformIdentity;
    }
}

@end
