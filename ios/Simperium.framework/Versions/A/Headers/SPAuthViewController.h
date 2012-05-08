//
//  SPAuthViewController.h
//  Simplecom
//
//  Created by Michael Johnston on 11-05-23.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Simperium;

/** This class is for signing in to any Simperium-powered app. Use it along with a nib layout to allow users to sign in or register as new users.
 */

@interface SPAuthViewController : UIViewController {
    IBOutlet UIButton *signInButton;
    IBOutlet UIImageView *icon;
    Simperium *_simperium;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil simperium:(Simperium *)simperium;
- (IBAction)pressSignIn:(id)sender;

@end
