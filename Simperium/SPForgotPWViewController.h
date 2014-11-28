//
//  SPForgotPWViewController.h
//  Simperium
//
//  Created by Patrick Vink on 11/28/14.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SPForgotPWViewController : UIViewController <UIWebViewDelegate> {
    
    UIWebView *webView;
    UIActivityIndicatorView *activityIndicator;
}

@end
