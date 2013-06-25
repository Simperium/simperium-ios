//
//  SPLoginViewController.m
//  Simperium
//
//  Created by Michael Johnston on 24/11/11.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SPLoginViewController.h"
#import "SPAuthenticationManager.h"
#import <Simperium/Simperium.h>
#import "ASIFormDataRequest.h"
#import <JSONKit/JSONKit.h>

@interface SPLoginViewController()
-(void)earthquake:(UIView*)itemView;
-(void)changeAction:(id)sender;
@end

@implementation SPLoginViewController
@synthesize tableView;
@synthesize authManager;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
	}
	return self;
}

- (void)dealloc {
	self.tableView = nil;
    self.authManager = nil;
    [cancelButton release];
	[super dealloc];
}

-(void)setCreating:(BOOL)bCreating
{
	creating = bCreating;
	
	NSString *actionTitle = creating ?
		NSLocalizedString(@"Sign Up", @"Title of button to create a new account (must be short)") :
		NSLocalizedString(@"Sign In", @"Title of button for logging in (must be short)");
	NSString *changeTitle = creating ?
		NSLocalizedString(@"Already have an account? Sign in", @"A short link to access the account login screen") :
		NSLocalizedString(@"Don't have an account? Sign up", @"A short link to access the account creation screen");
	[actionButton setTitle: actionTitle forState:UIControlStateNormal];
	[changeButton setTitle: changeTitle forState:UIControlStateNormal];	
}

-(BOOL)creating {
	return creating;
}

- (void)viewDidLoad {	
    // The cancel button will only be visible if there's a navigation controller, which will only happen
    // if authenticationOptional has been set on the Simperium instance.
    cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelAction:)];
    self.navigationItem.rightBarButtonItem = cancelButton;

	[createButton addTarget:self action:@selector(showCreateAction:) forControlEvents:UIControlEventTouchUpInside];
	createButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	[createButton setTitle: NSLocalizedString(@"Create an account", @"Button to create an account") forState:UIControlStateNormal];	
	
	[loginButton addTarget:self action:@selector(showLoginAction:) forControlEvents:UIControlEventTouchUpInside];
	loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	[loginButton setTitle: NSLocalizedString(@"I have an account", @"Button to use an existing account") forState:UIControlStateNormal];	
	self.tableView.hidden = YES;
	
	actionButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[actionButton addTarget:self action:@selector(goAction:) forControlEvents:UIControlEventTouchUpInside];
	actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	actionButton.frame = CGRectMake(self.tableView.frame.size.width/2-200/2, 0.0, 200, 40);
	actionButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin;
	
	changeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[changeButton addTarget:self action:@selector(changeAction:) forControlEvents:UIControlEventTouchUpInside];
	changeButton.titleLabel.font = [UIFont systemFontOfSize:14];
	[changeButton setTitleColor:[UIColor colorWithRed:59.0/255.0 green:86.0/255.0 blue:137.0/255.0 alpha:1.0] forState:UIControlStateNormal];
	[changeButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateHighlighted];
	changeButton.frame= CGRectMake(10, 50, self.tableView.frame.size.width-20, 40);
	changeButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	progressView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	progressView.frame = CGRectMake(actionButton.frame.size.width - 30, 9, 20, 20);
	[actionButton addSubview:progressView];
	
	UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 200)];
	footerView.contentMode = UIViewContentModeTopLeft;
	[footerView setUserInteractionEnabled:YES];
	[footerView addSubview:actionButton];
	[footerView addSubview:changeButton];
	footerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
	self.tableView.tableFooterView = footerView;
    [footerView release];
	
	self.creating = NO;
}

- (void)viewWillAppear:(BOOL)animated
{    
    self.tableView.scrollEnabled = NO;
    
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		self.tableView.scrollEnabled = NO;
        [self.tableView setBackgroundView:nil];
	}

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{    
	[[NSNotificationCenter defaultCenter] removeObserver: self name:UIKeyboardWillHideNotification object:nil];	
	[[NSNotificationCenter defaultCenter] removeObserver: self name:UIKeyboardWillShowNotification object:nil];	
}

-(void)keyboardWillHide:(NSNotification *)notification
{
	int keyboardHeight = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {	
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationCurve:[[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue]];
		[UIView setAnimationDuration:[[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
		[UIView setAnimationBeginsFromCurrentState:YES];
		CGRect rect = self.tableView.frame;
		rect.size.height -= keyboardHeight;
		rect.origin.y += keyboardHeight/4;
		self.tableView.frame = rect;
		
		[UIView commitAnimations];	
	} else {
		CGRect rect = self.tableView.frame;
		rect.size.height += keyboardHeight;
		self.tableView.frame = rect;
	}
}

-(void)keyboardWillShow:(NSNotification *)notification
{
	int keyboardHeight = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {	
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationCurve:[[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue]];
		[UIView setAnimationDuration:[[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
		[UIView setAnimationBeginsFromCurrentState:YES];
		CGRect rect = self.tableView.frame;
		rect.size.height += keyboardHeight;
		rect.origin.y -= keyboardHeight/4;
		self.tableView.frame = rect;
		
		[UIView commitAnimations];	
	} else {
		CGRect rect = self.tableView.frame;
		rect.size.height -= keyboardHeight;
		self.tableView.frame = rect;		
	}
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)	
		return YES;
	
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark Validation
-(BOOL)validateEmailWithAlerts:(BOOL)alert
{
	if (loginField.text.length == 0)
		return NO;
    NSString *emailRegEx = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
	NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegEx];
	if (loginField.text != nil && [emailTest evaluateWithObject:loginField.text] == NO) {
		if (alert) {
			// Bad email address
			NSString *title = NSLocalizedString(@"Invalid email", @"Title of dialog displayed when email address is invalid");
			NSString *message = NSLocalizedString(@"Your email address is not valid.", @"Message displayed when email address is invalid");
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title message:message
														   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
			[alert show];
			[alert release];
		}
		return NO;		
	}	
	return YES;
}

-(BOOL)validatePasswordWithAlerts:(BOOL)alert
{
	if (loginPasswordField.text == nil || [loginPasswordField.text length] < 4)
	{
		if (alert) {
			// Bad password
			NSString *title = NSLocalizedString(@"Invalid password", @"Title of a dialog displayed when password is invalid");
			NSString *message = NSLocalizedString(@"Password must contain at least 4 characters.", @"Message displayed when password is invalid");
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message
														   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
			[alert show];
			[alert release];	
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

-(void)showLoginAction:(id)sender
{	
	[loginField becomeFirstResponder];	
	tableView.alpha = 0;
	tableView.hidden = NO;
	[self.view bringSubviewToFront:tableView];
	[UIView beginAnimations:nil context:nil];
	tableView.alpha = 1.0;
	welcomeView.alpha = 0.0;
	[UIView commitAnimations];
}

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

    [self.authManager authenticateWithUsername:loginField.text password:loginPasswordField.text
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
                           
                         NSString *title = NSLocalizedString(@"Login failed", @"Title of a dialog displayed when login fails");
                         NSString *message = NSLocalizedString(@"Could not login with the provided email address and password.", @"Message displayed when login fails");
                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message
                                                                          delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
                         [alert show];
                         [alert release]; 
                       }
     ];
}

#pragma mark Creation

-(void)showCreateAction:(id)sender
{
	[self changeAction:sender];
	[loginField becomeFirstResponder];
	tableView.alpha = 0;
	tableView.hidden = NO;
	[self.view bringSubviewToFront:tableView];
	[UIView beginAnimations:nil context:nil];
	tableView.alpha = 1.0;
	welcomeView.alpha = 0.0;
	[UIView commitAnimations];
}

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
	CFPreferencesSetAppValue(CFSTR("email"), loginField.text, kCFPreferencesCurrentApplication);
	CFPreferencesSetAppValue(CFSTR("password"), loginPasswordField.text, kCFPreferencesCurrentApplication);
	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
	
	// Try to login and sync after entering password?
	[progressView setHidden: NO];
	[progressView startAnimating];
    [authManager createWithUsername:loginField.text password:loginPasswordField.text
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
                    NSString *title = NSLocalizedString(@"Account creation failed",
                                                        @"The title for a dialog that notifies you when account creation fails");
                    NSString *message = NSLocalizedString(@"Could not create an account with the provided email address and password.", @"An error message");
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message: message
                                                                   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
                    [alert show];
                    [alert release];
                }
     ];
}

-(void)failedDueToNetwork:(ASIHTTPRequest *)request
{
	[self restoreCreationSettings];
	NSString *title = NSLocalizedString(@"No connection",
										@"The title for a dialog that is displayed when there's a connection problem");
	NSString *message = NSLocalizedString(@"There's a problem with the connection.  Please try again later.",
										  @"Details for a dialog that is displayed when there's a connection problem");
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message
												   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
	[alert show];
	[alert release];	
}

#pragma mark Actions

-(void)changeAction:(id)sender
{
	self.creating = !self.creating;
    NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:2 inSection:0]];
    if (self.creating)
        [self.tableView insertRowsAtIndexPaths: indexPaths withRowAnimation:UITableViewRowAnimationTop];
    else
        [self.tableView deleteRowsAtIndexPaths: indexPaths withRowAnimation:UITableViewRowAnimationTop];
	[loginField becomeFirstResponder];
}

-(void)goAction:(id)sender
{
	if ([self validateDataWithAlerts:YES]) {
		if (self.creating) {
			if ([self validatePasswordConfirmation])
				[self performCreation];
		} else
			[self performLogin];
	}
}

-(void)cancelAction:(id)sender
{
    [authManager cancel];
}

#pragma mark Text Field

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
			if (self.creating) {
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


#pragma mark -
#pragma mark Table Data Source Methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return self.creating ? 3 : 2;
}

-(NSString*) tableView:(UITableView*) tView titleForHeaderInSection:(NSInteger)section
{
	return @"";
}

-(NSString*) tableView:(UITableView*) tView titleForFooterInSection:(NSInteger)section
{
    return @"";
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
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:EmailCellIdentifier] autorelease];
			cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
			
			loginField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 280, 25)];
			loginField.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
			loginField.clearsOnBeginEditing = NO;
			loginField.autocorrectionType = UITextAutocorrectionTypeNo;
			loginField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			loginField.keyboardType = UIKeyboardTypeEmailAddress;
			[loginField setDelegate:self];
			
			loginField.returnKeyType = UIReturnKeyNext;
			loginField.clearButtonMode = UITextFieldViewModeWhileEditing;
			loginField.placeholder = @"email@email.com";
			cell.accessoryView = loginField;	
		}
	} else if (indexPath.row == 1) {
		cell = [tView dequeueReusableCellWithIdentifier:PasswordCellIdentifier];		
		// Password
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PasswordCellIdentifier] autorelease];
			cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
			
			loginPasswordField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 280, 25)];
			loginPasswordField.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
			loginPasswordField.autocorrectionType = UITextAutocorrectionTypeNo;
			loginPasswordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			[loginPasswordField setDelegate:self];			
			loginPasswordField.secureTextEntry = YES;
			loginPasswordField.clearsOnBeginEditing = YES;
			loginPasswordField.placeholder = NSLocalizedString(@"Password", @"Hint displayed in the password field");
			cell.accessoryView = loginPasswordField;
		}
		
		loginPasswordField.returnKeyType = self.creating ? UIReturnKeyNext : UIReturnKeyGo;
	} else {
		cell = [tView dequeueReusableCellWithIdentifier:ConfirmCellIdentifier];		
		// Password
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ConfirmCellIdentifier] autorelease];
			cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
			
			loginPasswordConfirmField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 280, 25)];
			loginPasswordConfirmField.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
			loginPasswordConfirmField.autocorrectionType = UITextAutocorrectionTypeNo;
			loginPasswordConfirmField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			[loginPasswordConfirmField setDelegate:self];			
			loginPasswordConfirmField.returnKeyType = UIReturnKeyGo;
			loginPasswordConfirmField.secureTextEntry = YES;
			loginPasswordConfirmField.clearsOnBeginEditing = YES;
			loginPasswordConfirmField.placeholder = NSLocalizedString(@"Confirm", @"Hint displayed in the password confirmation field");
			cell.accessoryView = loginPasswordConfirmField;
		}
	}
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
	return cell;
}

#pragma mark Helpers
- (void)earthquake:(UIView*)itemView
{
    // From http://stackoverflow.com/a/1827373/1379066
    CGFloat t = 2.0;
	
    CGAffineTransform leftQuake  = CGAffineTransformTranslate(CGAffineTransformIdentity, t, -t);
    CGAffineTransform rightQuake = CGAffineTransformTranslate(CGAffineTransformIdentity, -t, t);
	
    itemView.transform = leftQuake;  // starting point
	
    [UIView beginAnimations:@"earthquake" context:itemView];
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
        UIView* item = (UIView *)context;
        item.transform = CGAffineTransformIdentity;
    }
}

@end
