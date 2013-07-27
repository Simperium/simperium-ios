//
//  AuthWindowController.m
//  Simplenote-OSX
//
//  Created by Brad Angelcyk on 2/14/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPAuthenticationWindowController.h"
#import <Simperium-OSX/Simperium.h>
#import <Simperium-OSX/NSString+Simperium.h>
#import <QuartzCore/CoreAnimation.h>
#import "SPAuthenticationWindow.h"
#import "SPAuthenticationView.h"
#import "SPAuthenticationTextField.h"
#import "SPAuthenticationButton.h"

static NSUInteger windowWidth = 380;
static NSUInteger windowHeight = 540;
static int minimumPasswordLength = 4;

@interface SPAuthenticationWindowController () {
    BOOL earthquaking;
}

@end

@implementation SPAuthenticationWindowController
@synthesize authManager;

- (id)init {
    rowSize = 50;
    SPAuthenticationWindow *window = [[SPAuthenticationWindow alloc] initWithContentRect:NSMakeRect(0, 0, windowWidth, windowHeight) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    
    if ((self = [super initWithWindow: window])) {
        SPAuthenticationView *authView = [[SPAuthenticationView alloc] initWithFrame:window.frame];
        [window.contentView addSubview:authView];
        
        NSUInteger paddingX = 30;
        NSUInteger width = windowWidth - paddingX*2;
        
        int cancelWidth = 60;
        cancelButton = [self linkButtonWithText:@"Skip" frame:NSMakeRect(windowWidth-cancelWidth, windowHeight-5-20, cancelWidth, 20)];
        cancelButton.target = self;
        cancelButton.action = @selector(cancelAction:);
        [authView addSubview:cancelButton];
        
        NSImage *logoImage = [NSImage imageNamed:@"logo"];
        CGFloat logoY = windowHeight-45-logoImage.size.height;
        NSRect logoRect = NSMakeRect(windowWidth/2 - logoImage.size.width/2, logoY, logoImage.size.width, logoImage.size.height);
        logoImageView = [[NSImageView alloc] initWithFrame:logoRect];
        logoImageView.image = logoImage;
        [authView addSubview:logoImageView];
        
        errorField = [self tipFieldWithText:@"" frame:NSMakeRect(paddingX, logoY - 30, width, 20)];
        [errorField setTextColor:[NSColor redColor]];
        [authView addSubview:errorField];

        logoY -= 30;
        usernameField = [[SPAuthenticationTextField alloc] initWithFrame:NSMakeRect(paddingX, logoY - rowSize, width, 40) secure:NO];
        
        [usernameField setPlaceholderString:@"Email Address"];
        usernameField.delegate = self;
        [authView addSubview:usernameField];
        
        passwordField = [[SPAuthenticationTextField alloc] initWithFrame:NSMakeRect(paddingX, logoY - rowSize*2, width, 40) secure:YES];
        [passwordField setPlaceholderString:@"Password"];
        
        passwordField.delegate = self;
        [authView addSubview:passwordField];

        confirmField = [[SPAuthenticationTextField alloc] initWithFrame:NSMakeRect(paddingX, logoY - rowSize*3, width, 40) secure:YES];
        [confirmField setPlaceholderString:@"Confirm Password"];
        confirmField.delegate = self;
        [authView addSubview:confirmField];
        
        logoY -= 30;
        signInButton = [[SPAuthenticationButton alloc] initWithFrame:NSMakeRect(paddingX, logoY - rowSize*3, width, 40)];
        signInButton.title = @"Sign In";
        signInButton.target = self;
        signInButton.action = @selector(signInAction:);
        [authView addSubview:signInButton];
        
        signUpButton = [[SPAuthenticationButton alloc] initWithFrame:NSMakeRect(paddingX, logoY - rowSize*4, width, 40)];
        signUpButton.title = @"Sign Up";
        signUpButton.target = self;
        signUpButton.action = @selector(signUpAction:);
        [authView addSubview:signUpButton];
        
        changeToSignUpField = [self tipFieldWithText:@"Already have an account?" frame:NSMakeRect(paddingX, logoY - rowSize*3 - 35, width, 20)];
        [authView addSubview:changeToSignUpField];

        changeToSignInField = [self tipFieldWithText:@"Need an account?" frame:NSMakeRect(paddingX, logoY - rowSize*4 - 35, width, 20)];
        [authView addSubview:changeToSignInField];
        
        logoY -= 5;
        changeToSignUpButton = [self toggleButtonWithText:@"Sign Up" frame:NSMakeRect(paddingX, changeToSignUpField.frame.origin.y - changeToSignUpField.frame.size.height - 5, width, 30)];
        [authView addSubview:changeToSignUpButton];
        
        changeToSignInButton = [self toggleButtonWithText:@"Sign In" frame:NSMakeRect(paddingX, changeToSignInField.frame.origin.y - changeToSignInField.frame.size.height - 5, width, 30)];
        [authView addSubview:changeToSignInButton];
        
        // Enter sign up mode
        [self toggleAuthenticationMode:signUpButton];        
    }
    
    return self;
}

- (void)setOptional:(BOOL)on {
    optional = on;
    [cancelButton setHidden:!optional];
}

- (BOOL)optional {
    return optional;
}

- (NSTextField *)tipFieldWithText:(NSString *)text frame:(CGRect)frame {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    [field setStringValue:[text uppercaseString]];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setAlignment:NSCenterTextAlignment];
    [field setFont:[NSFont fontWithName:@"SourceSansPro-Semibold" size:13]];
    [field setTextColor:[NSColor colorWithCalibratedWhite:153.f/255.f alpha:1.0]];
    
    return field;
}

- (NSButton *)linkButtonWithText:(NSString *)text frame:(CGRect)frame {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    [button setBordered:NO];
    [button setButtonType:NSMomentaryChangeButton];
    button.target = self;
    button.action = @selector(toggleAuthenticationMode:);
    [button setFont:[NSFont fontWithName:@"SourceSansPro-Semibold" size:13]];
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setAlignment:NSCenterTextAlignment];
    NSColor *linkColor = [NSColor colorWithCalibratedRed:65.f/255.f green:137.f/255.f blue:199.f/255.f alpha:1.0];

    
    NSDictionary *attributes = @{NSFontAttributeName : [NSFont fontWithName:@"SourceSansPro-Semibold" size:13],
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
    signingIn = sender == changeToSignInButton;
    [signInButton setHidden:!signingIn];
    [signInButton setEnabled:signingIn];
    [signUpButton setHidden:signingIn];
    [signUpButton setEnabled:!signingIn];
    [changeToSignInButton setHidden:signingIn];
    [changeToSignInButton setEnabled:!signingIn];
    [changeToSignUpButton setHidden:!signingIn];
    [changeToSignUpButton setEnabled:signingIn];
    [changeToSignInField setHidden:signingIn];
    [changeToSignUpField setHidden:!signingIn];
    [confirmField setHidden:signingIn];
    
    [self.window.contentView setNeedsDisplay:YES];
    [self clearAuthenticationError];
}


#pragma mark Actions

- (IBAction)signInAction:(id)sender {
    if (![self validateSignIn]) {
        return;
    }
    
    signInButton.title = @"Signing In...";
    [signInButton setEnabled:NO];
    [changeToSignUpButton setEnabled:NO];
    [usernameField setEnabled:NO];
    [passwordField setEnabled:NO];
    [self.authManager authenticateWithUsername:[usernameField stringValue] password:[passwordField stringValue]
                                       success:^{
                                       }
                                       failure:^(int responseCode, NSString *responseString) {
                                           NSLog(@"Error signing in (%d): %@", responseCode, responseString);
                                           [self showAuthenticationErrorForCode:responseCode];
                                           signInButton.title = @"Sign In";
                                           [signInButton setEnabled:YES];
                                           [changeToSignUpButton setEnabled:YES];
                                           [usernameField setEnabled:YES];
                                           [passwordField setEnabled:YES];
                                       }
     ];
}

- (IBAction)signUpAction:(id)sender {
    if (![self validateSignUp]) {
        return;
    }
    
    signUpButton.title = @"Signing Up...";
    [signUpButton setEnabled:NO];
    [changeToSignInButton setEnabled:NO];
    [usernameField setEnabled:NO];
    [passwordField setEnabled:NO];
    [confirmField setEnabled:NO];

    [self.authManager createWithUsername:[usernameField stringValue] password:[passwordField stringValue]
                                 success:^{
                                     //[self close];
                                 }
                                 failure:^(int responseCode, NSString *responseString) {
                                     NSLog(@"Error signing up (%d): %@", responseCode, responseString);
                                     [self showAuthenticationErrorForCode:responseCode];
                                     signUpButton.title = @"Sign Up";
                                     [signUpButton setEnabled:YES];
                                     [changeToSignInButton setEnabled:YES];
                                     [usernameField setEnabled:YES];
                                     [passwordField setEnabled:YES];
                                     [confirmField setEnabled:YES];
                                 }];
}

- (IBAction)cancelAction:(id)sender {
    [authManager cancel];
}


# pragma mark Validation and Error Handling

- (BOOL)isValidEmail:(NSString *)checkString {
    // From http://stackoverflow.com/a/3638271/1379066
    BOOL stricterFilter = YES; // Discussion http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/
    NSString *stricterFilterString = @"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}";
    NSString *laxString = @".+@([A-Za-z0-9]+\\.)+[A-Za-z]{2}[A-Za-z]*";
    NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    
    return [emailTest evaluateWithObject:checkString];
}

- (BOOL)validateUsername {
    // Expect email addresses by default
    if (![self isValidEmail:usernameField.stringValue]) {
        [self earthquake:usernameField];
        [self showAuthenticationError:@"Not a valid email address"];
        
        return NO;
    }

    return YES;
}

- (BOOL)validatePasswordSecurity {
    if (passwordField.stringValue.length < minimumPasswordLength) {
        [self earthquake:passwordField];
        [self earthquake:confirmField];
        
        NSString *notLongEnough = [NSString stringWithFormat:@"Password should be at least %d characters", minimumPasswordLength];
        [self showAuthenticationError:notLongEnough];
        
        return NO;
    }
    
    // Could enforce other requirements here

    return YES;
}

- (BOOL)validatePasswordsMatch{
    if (![passwordField.stringValue isEqualToString:confirmField.stringValue]) {
        [self earthquake:passwordField];
        [self earthquake:confirmField];

        return NO;
    }
    
    return YES;
}

- (BOOL)validateConnection {
    if (!authManager.connected) {
        [self showAuthenticationError:@"You're not connected to the internet"];
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
    if (earthquaking)
        return;
    
    earthquaking = YES;
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
    earthquaking = NO;
}

- (void)showAuthenticationError:(NSString *)errorMessage {
    [errorField setStringValue:errorMessage];
}

- (void)showAuthenticationErrorForCode:(NSUInteger)responseCode {
    switch (responseCode) {
        case 409:
            // User already exists
            [self showAuthenticationError:@"That email is already being used"];
            [self earthquake:usernameField];
            [[self window] makeFirstResponder:usernameField];
            break;
        case 401:
            // Bad email or password
            [self showAuthenticationError:@"Bad email or password"];
            break;

        default:
            // General network problem
            [self showAuthenticationError:@"We're having problems. Please try again soon."];
            break;
    }
}

- (void)clearAuthenticationError {
    [errorField setStringValue:@""];
}

#pragma mark NSTextView delegates

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    BOOL retval = NO;
    
    if (commandSelector == @selector(insertNewline:)) {
        if (signingIn && [control isEqual:passwordField.textField]) {
            [self signInAction:nil];
        } else if (!signingIn && [control isEqual:confirmField.textField]) {
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
    if ([[NSApp currentEvent].charactersIgnoringModifiers isEqualToString:@"\r"]) {
        if (signingIn && [[obj object] isEqual:passwordField.textField]) {
            [self signInAction:nil];
        } else if (!signingIn && [[obj object] isEqual:confirmField.textField]) {
            [self signUpAction:nil];
        }
    }
}


@end
