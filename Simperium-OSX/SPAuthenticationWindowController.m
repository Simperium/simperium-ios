//
//  SPAuthenticationWindowController.m
//  Simperium
//
//  Created by Michael Johnston on 8/14/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPAuthenticationWindowController.h"
#import "Simperium.h"
#import "NSString+Simperium.h"
#import <QuartzCore/CoreAnimation.h>
#import "SPAuthenticator.h"
#import "SPAuthenticationWindow.h"
#import "SPAuthenticationView.h"
#import "SPAuthenticationTextField.h"
#import "SPAuthenticationButton.h"
#import "SPAuthenticationConfiguration.h"
#import "SPAuthenticationValidator.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static CGFloat const SPAuthenticationWindowWidth        = 380.0f;
static CGFloat const SPAuthenticationWindowHeight       = 540.0f;
static CGFloat const SPAuthenticationRowSize            = 50;

static CGFloat const SPAuthenticationCancelWidth        = 60.0f;

static CGFloat const SPAuthenticationFieldPaddingX      = 30.0f;
static CGFloat const SPAuthenticationFieldWidth         = SPAuthenticationWindowWidth - SPAuthenticationFieldPaddingX * 2;
static CGFloat const SPAuthenticationFieldHeight        = 40.0f;

static CGFloat const SPAuthenticationProgressSize       = 20.0f;


#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPAuthenticationWindowController () <NSTextFieldDelegate, CAAnimationDelegate>
@property (nonatomic, strong) NSImageView               *logoImageView;
@property (nonatomic, strong) NSButton                  *cancelButton;
@property (nonatomic, strong) SPAuthenticationTextField *usernameField;
@property (nonatomic, strong) SPAuthenticationTextField *passwordField;
@property (nonatomic, strong) SPAuthenticationTextField *confirmField;
@property (nonatomic, strong) NSTextField               *changeToSignInField;
@property (nonatomic, strong) NSTextField               *changeToSignUpField;
@property (nonatomic, strong) NSTextField               *errorField;
@property (nonatomic, strong) NSButton                  *signInButton;
@property (nonatomic, strong) NSButton                  *signUpButton;
@property (nonatomic, strong) NSButton                  *forgotPasswordButton;
@property (nonatomic, strong) NSButton                  *changeToSignInButton;
@property (nonatomic, strong) NSButton                  *changeToSignUpButton;
@property (nonatomic, strong) NSProgressIndicator       *signInProgress;
@property (nonatomic, strong) NSProgressIndicator       *signUpProgress;
@property (nonatomic, assign) BOOL                      earthquaking;
@end


#pragma mark ====================================================================================
#pragma mark SPAuthenticationWindowController
#pragma mark ====================================================================================

@implementation SPAuthenticationWindowController

- (instancetype)init {
    SPAuthenticationWindow *window = [[SPAuthenticationWindow alloc] initWithContentRect:NSMakeRect(0, 0, SPAuthenticationWindowWidth, SPAuthenticationWindowHeight) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    
    if ((self = [super initWithWindow: window])) {
        self.validator = [[SPAuthenticationValidator alloc] init];
        
        SPAuthenticationView *authView = [[SPAuthenticationView alloc] initWithFrame:window.frame];
        [window.contentView addSubview:authView];
        
        NSString *cancelButtonText = NSLocalizedString(@"Skip", @"Text to display on OSX cancel button");

        self.cancelButton = [self linkButtonWithText:cancelButtonText frame:NSMakeRect(SPAuthenticationWindowWidth-SPAuthenticationCancelWidth, SPAuthenticationWindowHeight-5-20, SPAuthenticationCancelWidth, 20)];
        self.cancelButton.target = self;
        self.cancelButton.action = @selector(cancelAction:);
        [authView addSubview:self.cancelButton];
        
        NSImage *logoImage = [NSImage imageNamed:[[SPAuthenticationConfiguration sharedInstance] logoImageName]];
        CGFloat markerY = SPAuthenticationWindowHeight-45-logoImage.size.height;
        NSRect logoRect = NSMakeRect(SPAuthenticationWindowWidth * 0.5f - logoImage.size.width * 0.5f, markerY, logoImage.size.width, logoImage.size.height);
        self.logoImageView = [[NSImageView alloc] initWithFrame:logoRect];
        self.logoImageView.image = logoImage;
        [authView addSubview:self.logoImageView];
        
        self.errorField = [self tipFieldWithText:@"" frame:NSMakeRect(SPAuthenticationFieldPaddingX, markerY - 30, SPAuthenticationFieldWidth, 20)];
        [self.errorField setTextColor:[NSColor redColor]];
        [authView addSubview:self.errorField];

        markerY -= 30;
        self.usernameField = [[SPAuthenticationTextField alloc] initWithFrame:NSMakeRect(SPAuthenticationFieldPaddingX, markerY - SPAuthenticationRowSize, SPAuthenticationFieldWidth, SPAuthenticationFieldHeight) secure:NO];
        [self.usernameField setPlaceholderString:NSLocalizedString(@"Email", @"Placeholder text for login field")];
        self.usernameField.delegate = self;
        [authView addSubview:self.usernameField];
        
        self.passwordField = [[SPAuthenticationTextField alloc] initWithFrame:NSMakeRect(SPAuthenticationFieldPaddingX, markerY - SPAuthenticationRowSize*2, SPAuthenticationFieldWidth, SPAuthenticationFieldHeight) secure:YES];
        [self.passwordField setPlaceholderString:NSLocalizedString(@"Password", @"Placeholder text for password field")];
        
        self.passwordField.delegate = self;
        [authView addSubview:self.passwordField];

        self.confirmField = [[SPAuthenticationTextField alloc] initWithFrame:NSMakeRect(SPAuthenticationFieldPaddingX, markerY - SPAuthenticationRowSize*3, SPAuthenticationFieldWidth, SPAuthenticationFieldHeight) secure:YES];
        [self.confirmField setPlaceholderString:NSLocalizedString(@"Confirm Password", @"Placeholder text for confirmation field")];
        self.confirmField.delegate = self;
        [authView addSubview:self.confirmField];
                
        markerY -= 30;
        self.signInButton = [[SPAuthenticationButton alloc] initWithFrame:NSMakeRect(SPAuthenticationFieldPaddingX, markerY - SPAuthenticationRowSize*3, SPAuthenticationFieldWidth, SPAuthenticationFieldHeight)];
        self.signInButton.title = NSLocalizedString(@"Sign In", @"Title of button for signing in");
        self.signInButton.target = self;
        self.signInButton.action = @selector(signInAction:);
        [authView addSubview:self.signInButton];

        self.signInProgress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(self.signInButton.frame.size.width - SPAuthenticationProgressSize - SPAuthenticationFieldPaddingX, (self.signInButton.frame.size.height - SPAuthenticationProgressSize) * 0.5f, SPAuthenticationProgressSize, SPAuthenticationProgressSize)];
        [self.signInProgress setStyle:NSProgressIndicatorSpinningStyle];
        [self.signInProgress setDisplayedWhenStopped:NO];
        [self.signInButton addSubview:self.signInProgress];

        self.signUpButton = [[SPAuthenticationButton alloc] initWithFrame:NSMakeRect(SPAuthenticationFieldPaddingX, markerY - SPAuthenticationRowSize*4, SPAuthenticationFieldWidth, SPAuthenticationFieldHeight)];
        self.signUpButton.title = NSLocalizedString(@"Sign Up", @"Title of button for signing up");
        self.signUpButton.target = self;
        self.signUpButton.action = @selector(signUpAction:);
        [authView addSubview:self.signUpButton];
        
        self.signUpProgress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(self.signUpProgress.frame.size.width - SPAuthenticationProgressSize - SPAuthenticationFieldPaddingX, (self.signUpProgress.frame.size.height - SPAuthenticationProgressSize) * 0.5f, SPAuthenticationProgressSize, SPAuthenticationProgressSize)];
        [self.signUpProgress setStyle:NSProgressIndicatorSpinningStyle];
        [self.signUpProgress setDisplayedWhenStopped:NO];
        [self.signUpButton addSubview:self.signUpProgress];

        // Forgot Password!
        self.forgotPasswordButton = [self linkButtonWithText:@"Forgot your Password?" frame:NSMakeRect(SPAuthenticationFieldPaddingX, markerY - SPAuthenticationRowSize*3 - 35, SPAuthenticationFieldWidth, 20)];
        self.forgotPasswordButton.target = self;
        self.forgotPasswordButton.action = @selector(forgotPassword:);
        [authView addSubview:self.forgotPasswordButton];
        
        // Toggle Signup
        NSString *signUpTip = NSLocalizedString(@"Need an account?", @"Link to create an account");
        self.changeToSignUpField = [self tipFieldWithText:signUpTip frame:NSMakeRect(SPAuthenticationFieldPaddingX, markerY - SPAuthenticationRowSize*4 - 35, SPAuthenticationFieldWidth, 20)];
        [authView addSubview:self.changeToSignUpField];

        self.changeToSignUpButton = [self toggleButtonWithText:self.signUpButton.title frame:NSMakeRect(SPAuthenticationFieldPaddingX, self.changeToSignUpField.frame.origin.y - self.changeToSignUpField.frame.size.height - 2, SPAuthenticationFieldWidth, 30)];
        [authView addSubview:self.changeToSignUpButton];
        
        // Toggle SignIn
        NSString *signInTip = NSLocalizedString(@"Already have an account?", @"Link to sign in to an account");
        self.changeToSignInField = [self tipFieldWithText:signInTip frame:NSMakeRect(SPAuthenticationFieldPaddingX, markerY - SPAuthenticationRowSize*4 - 35, SPAuthenticationFieldWidth, 20)];
        [authView addSubview:self.changeToSignInField];
        
        self.changeToSignInButton = [self toggleButtonWithText:self.signInButton.title frame:NSMakeRect(SPAuthenticationFieldPaddingX, self.changeToSignInField.frame.origin.y - self.changeToSignInField.frame.size.height - 2, SPAuthenticationFieldWidth, 30)];
        [authView addSubview:self.changeToSignInButton];
        
        // Enter sign up mode
        [self toggleAuthenticationMode:self.signUpButton];
    }
    
    return self;
}

- (void)setOptional:(BOOL)on {
    _optional = on;
    [self.cancelButton setHidden:!_optional];
}

- (NSTextField *)tipFieldWithText:(NSString *)text frame:(CGRect)frame {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    NSFont *font = [NSFont fontWithName:[SPAuthenticationConfiguration sharedInstance].mediumFontName size:13];
    [field setStringValue:[text uppercaseString]];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setAlignment:NSCenterTextAlignment];
    [field setFont:font];
    [field setTextColor:[NSColor colorWithCalibratedWhite:153.f/255.f alpha:1.0]];
    
    return field;
}

- (NSButton *)linkButtonWithText:(NSString *)text frame:(CGRect)frame {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    [button setBordered:NO];
    [button setButtonType:NSMomentaryChangeButton];
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setAlignment:NSCenterTextAlignment];
    NSColor *linkColor = [SPAuthenticationConfiguration sharedInstance].controlColor;
    
    NSFont *font = [NSFont fontWithName:[SPAuthenticationConfiguration sharedInstance].mediumFontName size:13];
    NSDictionary *attributes = @{NSFontAttributeName : font,
                                 NSForegroundColorAttributeName : linkColor,
                                 NSParagraphStyleAttributeName : style};
    [button setAttributedTitle: [[NSAttributedString alloc] initWithString:[text uppercaseString] attributes:attributes]];
    
    return button;
}

- (NSButton *)toggleButtonWithText:(NSString *)text frame:(CGRect)frame {
    NSButton *button = [self linkButtonWithText:text frame:frame];
    button.target = self;
    button.action = @selector(toggleAuthenticationMode:);

    return button;
}

- (IBAction)forgotPassword:(id)sender {
    NSString *forgotPasswordURL = [[SPAuthenticationConfiguration sharedInstance] forgotPasswordURL];
    
    // Post the email already entered in the Username Field. This allows us to prefill the Forgot Password Form
    NSString *username = self.usernameField.stringValue.sp_trim;
    if (username.length) {
        NSString *parameters = [NSString stringWithFormat:@"?email=%@", username];
        forgotPasswordURL = [forgotPasswordURL stringByAppendingString:parameters];
    }
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:forgotPasswordURL]];
}

- (IBAction)toggleAuthenticationMode:(id)sender {
	self.signingIn = (sender == self.changeToSignInButton);
}

- (void)setSigningIn:(BOOL)signingIn {
    _signingIn = signingIn;
	[self refreshFields];
}

- (void)refreshFields {
    // Refresh Buttons
    [self.signInButton setHidden:!_signingIn];
    [self.signInButton setEnabled:_signingIn];
    [self.signUpButton setHidden:_signingIn];
    [self.signUpButton setEnabled:!_signingIn];
    [self.changeToSignInButton setHidden:_signingIn];
    [self.changeToSignInButton setEnabled:!_signingIn];
    [self.changeToSignUpButton setHidden:!_signingIn];
    [self.changeToSignUpButton setEnabled:_signingIn];
    [self.changeToSignInField setHidden:_signingIn];
    [self.changeToSignUpField setHidden:!_signingIn];
    [self.confirmField setHidden:_signingIn];
    
    // Remove any pending errors
    [self clearAuthenticationError];
    
    // Forgot Password
    BOOL shouldDisplayForgotPassword = _signingIn && [[SPAuthenticationConfiguration sharedInstance] forgotPasswordURL];
    [self.forgotPasswordButton setHidden:!shouldDisplayForgotPassword];
    
    // Refresh the entire View
    [self.window.contentView setNeedsDisplay:YES];
}


#pragma mark Actions

- (IBAction)signInAction:(id)sender {
    if (![self validateSignIn]) {
        return;
    }
    
    self.signInButton.title = NSLocalizedString(@"Signing In...", @"Displayed temporarily while signing in");
    [self.signInProgress startAnimation:self];
    [self.signInButton setEnabled:NO];
    [self.changeToSignUpButton setEnabled:NO];
    [self.usernameField setEnabled:NO];
    [self.passwordField setEnabled:NO];
    [self.authenticator authenticateWithUsername:self.usernameField.stringValue.sp_trim
                                        password:self.passwordField.stringValue
                                       success:^{
                                       }
                                       failure:^(int responseCode, NSString *responseString) {
                                           NSLog(@"Error signing in (%d): %@", responseCode, responseString);
                                           [self showAuthenticationErrorForCode:responseCode];
                                           [self.signInProgress stopAnimation:self];
                                           self.signInButton.title = NSLocalizedString(@"Sign In", @"Title of button for signing in");
                                           [self.signInButton setEnabled:YES];
                                           [self.changeToSignUpButton setEnabled:YES];
                                           [self.usernameField setEnabled:YES];
                                           [self.passwordField setEnabled:YES];
                                       }
     ];
}

- (IBAction)signUpAction:(id)sender {
    if (![self validateSignUp]) {
        return;
    }
    
    self.signUpButton.title = NSLocalizedString(@"Signing Up...", @"Displayed temoprarily while signing up");
    [self.signUpProgress startAnimation:self];
    [self.signUpButton setEnabled:NO];
    [self.changeToSignInButton setEnabled:NO];
    [self.usernameField setEnabled:NO];
    [self.passwordField setEnabled:NO];
    [self.confirmField setEnabled:NO];

    [self.authenticator createWithUsername:self.usernameField.stringValue.sp_trim
                                  password:self.passwordField.stringValue
                                 success:^{
                                     //[self close];
                                 }
                                 failure:^(int responseCode, NSString *responseString) {
                                     NSLog(@"Error signing up (%d): %@", responseCode, responseString);
                                     [self showAuthenticationErrorForCode:responseCode];
                                     self.signUpButton.title = NSLocalizedString(@"Sign Up", @"Title of button for signing up");
                                     [self.signUpProgress stopAnimation:self];
                                     [self.signUpButton setEnabled:YES];
                                     [self.changeToSignInButton setEnabled:YES];
                                     [self.usernameField setEnabled:YES];
                                     [self.passwordField setEnabled:YES];
                                     [self.confirmField setEnabled:YES];
                                 }];
}

- (IBAction)cancelAction:(id)sender {
    [self.authenticator cancel];
}


# pragma mark Validation and Error Handling

- (BOOL)validateUsername {
    if (![self.validator validateUsername:self.usernameField.stringValue.sp_trim]) {
        [self earthquake:self.usernameField];
        [self showAuthenticationError:NSLocalizedString(@"Not a valid email address", @"Error when you enter a bad email address")];
        
        return NO;
    }

    return YES;
}

- (BOOL)validatePasswordSecurity {
    if (![self.validator validatePasswordSecurity:self.passwordField.stringValue]) {
        [self earthquake:self.passwordField];
        [self earthquake:self.confirmField];
        
        NSString *errorStr = NSLocalizedString(@"Password should be at least %ld characters", @"Error when your password isn't long enough");
        NSString *notLongEnough = [NSString stringWithFormat:errorStr, (long)self.validator.minimumPasswordLength];
        [self showAuthenticationError:notLongEnough];
        
        return NO;
    }
    
    return YES;
}

- (BOOL)validatePasswordsMatch{
    if (![self.passwordField.stringValue isEqualToString:self.confirmField.stringValue]) {
        [self earthquake:self.passwordField];
        [self earthquake:self.confirmField];

        return NO;
    }
    
    return YES;
}

- (BOOL)validateConnection {
    if (!self.authenticator.connected) {
        [self showAuthenticationError:NSLocalizedString(@"You're not connected to the internet", @"Error when you're not connected")];
        return NO;
    }
    
    return YES;
}

- (BOOL)validateSignIn {
    [self clearAuthenticationError];
    return [self validateConnection] &&
           [self validateUsername] &&
           [self validatePasswordSecurity];
}

- (BOOL)validateSignUp {
    [self clearAuthenticationError];
    return [self validateConnection] &&
           [self validateUsername] &&
           [self validatePasswordsMatch] &&
           [self validatePasswordSecurity];
}

- (void)earthquake:(NSView *)view {
    // Quick and dirty way to prevent overlapping animations that can move the view
    if (self.earthquaking) {
        return;
    }
    
    self.earthquaking = YES;
    CAKeyframeAnimation *shakeAnimation = [self shakeAnimation:view.frame];
    [view setAnimations:@{@"frameOrigin":shakeAnimation}];
	[[view animator] setFrameOrigin:view.frame.origin];
}

- (CAKeyframeAnimation *)shakeAnimation:(NSRect)frame
{
    // From http://www.cimgf.com/2008/02/27/core-animation-tutorial-window-shake-effect/
    int numberOfShakes = 4;
    CGFloat vigourOfShake = 0.02;
    CGFloat durationOfShake = 0.5;
    
    CAKeyframeAnimation *shakeAnimation = [CAKeyframeAnimation animation];
	
    CGMutablePathRef shakePath = CGPathCreateMutable();
    CGPathMoveToPoint(shakePath, NULL, NSMinX(frame), NSMinY(frame));
	int index;
	for (index = 0; index < numberOfShakes; ++index)
	{
		CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) - frame.size.width * vigourOfShake, NSMinY(frame));
		CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) + frame.size.width * vigourOfShake, NSMinY(frame));
	}
    CGPathCloseSubpath(shakePath);
    shakeAnimation.path = shakePath;
    shakeAnimation.duration = durationOfShake;
    shakeAnimation.delegate = self;
    
    return shakeAnimation;
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    self.earthquaking = NO;
}

- (void)showAuthenticationError:(NSString *)errorMessage {
    [self.errorField setStringValue:errorMessage];
}

- (void)showAuthenticationErrorForCode:(NSUInteger)responseCode {
    switch (responseCode) {
        case 409:
            // User already exists
            [self showAuthenticationError:NSLocalizedString(@"That email is already being used", @"Error when address is in use")];
            [self earthquake:self.usernameField];
            [self.window makeFirstResponder:self.usernameField];
            break;
        case 401:
            // Bad email or password
            [self showAuthenticationError:NSLocalizedString(@"Bad email or password", @"Error for bad email or password")];
            break;

        default:
            // General network problem
            [self showAuthenticationError:NSLocalizedString(@"We're having problems. Please try again soon.", @"Generic error")];
            break;
    }
}

- (void)clearAuthenticationError {
    [self.errorField setStringValue:@""];
}

#pragma mark NSTextView delegates

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector {
    BOOL retval = NO;
    
    if (commandSelector == @selector(insertNewline:)) {
        if (_signingIn && [control isEqual:self.passwordField.textField]) {
            [self signInAction:nil];
        } else if (!_signingIn && [control isEqual:self.confirmField.textField]) {
            [self signUpAction:nil];
        }
    }
    
    return retval;
}

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor {
    [self.window.contentView setNeedsDisplay:YES];
    return YES;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    // Intercept return and invoke actions
    NSEvent *currentEvent = [NSApp currentEvent];
    if (currentEvent.type == NSKeyDown && [currentEvent.charactersIgnoringModifiers isEqualToString:@"\r"]) {
        if (_signingIn && [[obj object] isEqual:self.passwordField.textField]) {
            [self signInAction:nil];
        } else if (!_signingIn && [[obj object] isEqual:self.confirmField.textField]) {
            [self signUpAction:nil];
        }
    }
}

@end
