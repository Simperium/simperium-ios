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

static NSUInteger windowWidth = 380;
static NSUInteger windowHeight = 540;
static NSInteger rowSize = 50;

#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPAuthenticationWindowController () <NSTextFieldDelegate>
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
    SPAuthenticationWindow *window = [[SPAuthenticationWindow alloc] initWithContentRect:NSMakeRect(0, 0, windowWidth, windowHeight) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    
    if ((self = [super initWithWindow: window])) {
        self.validator = [[SPAuthenticationValidator alloc] init];
        
        SPAuthenticationView *authView = [[SPAuthenticationView alloc] initWithFrame:window.frame];
        [window.contentView addSubview:authView];
        
        NSUInteger paddingX = 30;
        NSUInteger width = windowWidth - paddingX*2;
        
        int cancelWidth = 60;
        NSString *cancelButtonText = NSLocalizedString(@"Skip", @"Text to display on OSX cancel button");

        self.cancelButton = [self linkButtonWithText:cancelButtonText frame:NSMakeRect(windowWidth-cancelWidth, windowHeight-5-20, cancelWidth, 20)];
        self.cancelButton.target = self;
        self.cancelButton.action = @selector(cancelAction:);
        [authView addSubview:self.cancelButton];
        
        NSImage *logoImage = [NSImage imageNamed:[[SPAuthenticationConfiguration sharedInstance] logoImageName]];
        CGFloat markerY = windowHeight-45-logoImage.size.height;
        NSRect logoRect = NSMakeRect(windowWidth/2 - logoImage.size.width/2, markerY, logoImage.size.width, logoImage.size.height);
        self.logoImageView = [[NSImageView alloc] initWithFrame:logoRect];
        self.logoImageView.image = logoImage;
        [authView addSubview:self.logoImageView];
        
        self.errorField = [self tipFieldWithText:@"" frame:NSMakeRect(paddingX, markerY - 30, width, 20)];
        [self.errorField setTextColor:[NSColor redColor]];
        [authView addSubview:self.errorField];

        markerY -= 30;
        self.usernameField = [[SPAuthenticationTextField alloc] initWithFrame:NSMakeRect(paddingX, markerY - rowSize, width, 40) secure:NO];
        
        [self.usernameField setPlaceholderString:NSLocalizedString(@"Email Address", @"Placeholder text for login field")];
        self.usernameField.delegate = self;
        [authView addSubview:self.usernameField];
        
        self.passwordField = [[SPAuthenticationTextField alloc] initWithFrame:NSMakeRect(paddingX, markerY - rowSize*2, width, 40) secure:YES];
        [self.passwordField setPlaceholderString:NSLocalizedString(@"Password", @"Placeholder text for password field")];
        
        self.passwordField.delegate = self;
        [authView addSubview:self.passwordField];

        self.confirmField = [[SPAuthenticationTextField alloc] initWithFrame:NSMakeRect(paddingX, markerY - rowSize*3, width, 40) secure:YES];
        [self.confirmField setPlaceholderString:NSLocalizedString(@"Confirm Password", @"Placeholder text for confirmation field")];
        self.confirmField.delegate = self;
        [authView addSubview:self.confirmField];
                
        markerY -= 30;
        self.signInButton = [[SPAuthenticationButton alloc] initWithFrame:NSMakeRect(paddingX, markerY - rowSize*3, width, 40)];
        self.signInButton.title = NSLocalizedString(@"Sign In", @"Title of button for signing in");
        self.signInButton.target = self;
        self.signInButton.action = @selector(signInAction:);
        [authView addSubview:self.signInButton];

        int progressSize = 20;
        self.signInProgress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(self.signInButton.frame.size.width - progressSize - paddingX, (self.signInButton.frame.size.height - progressSize) / 2, progressSize, progressSize)];
        [self.signInProgress setStyle:NSProgressIndicatorSpinningStyle];
        [self.signInProgress setDisplayedWhenStopped:NO];
        [self.signInButton addSubview:self.signInProgress];

        
        self.signUpButton = [[SPAuthenticationButton alloc] initWithFrame:NSMakeRect(paddingX, markerY - rowSize*4, width, 40)];
        self.signUpButton.title = NSLocalizedString(@"Sign Up", @"Title of button for signing up");
        self.signUpButton.target = self;
        self.signUpButton.action = @selector(signUpAction:);
        [authView addSubview:self.signUpButton];
        
        self.signUpProgress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(self.signUpProgress.frame.size.width - progressSize - paddingX, (self.signUpProgress.frame.size.height - progressSize) / 2, progressSize, progressSize)];
        [self.signUpProgress setStyle:NSProgressIndicatorSpinningStyle];
        [self.signUpProgress setDisplayedWhenStopped:NO];
        [self.signUpButton addSubview:self.signUpProgress];
        
        // Toggle Signup
        NSString *signUpTip = NSLocalizedString(@"Need an account?", @"Link to create an account");
        self.changeToSignUpField = [self tipFieldWithText:signUpTip frame:NSMakeRect(paddingX, markerY - rowSize*3 - 35, width, 20)];
        [authView addSubview:self.changeToSignUpField];

        self.changeToSignUpButton = [self toggleButtonWithText:self.signUpButton.title frame:NSMakeRect(paddingX, self.changeToSignUpField.frame.origin.y - self.changeToSignUpField.frame.size.height - 2, width, 30)];
        [authView addSubview:self.changeToSignUpButton];
        
        // Toggle SignIn
        NSString *signInTip = NSLocalizedString(@"Already have an account?", @"Link to sign in to an account");
        self.changeToSignInField = [self tipFieldWithText:signInTip frame:NSMakeRect(paddingX, markerY - rowSize*4 - 35, width, 20)];
        [authView addSubview:self.changeToSignInField];
        
        self.changeToSignInButton = [self toggleButtonWithText:self.signInButton.title frame:NSMakeRect(paddingX, self.changeToSignInField.frame.origin.y - self.changeToSignInField.frame.size.height - 2, width, 30)];
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
    button.target = self;
    button.action = @selector(toggleAuthenticationMode:);
    
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


- (IBAction)toggleAuthenticationMode:(id)sender {
	self.signingIn = (sender == self.changeToSignInButton);
}

- (void)setSigningIn:(BOOL)signingIn {
    _signingIn = signingIn;
	[self refreshFields];
}

- (void)refreshFields {
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
    
    [self.window.contentView setNeedsDisplay:YES];
    [self clearAuthenticationError];
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
    [self.authenticator authenticateWithUsername:[self.usernameField stringValue] password:[self.passwordField stringValue]
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

    [self.authenticator createWithUsername:[self.usernameField stringValue] password:[self.passwordField stringValue]
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
    if (![self.validator validateUsername:self.usernameField.stringValue]) {
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
