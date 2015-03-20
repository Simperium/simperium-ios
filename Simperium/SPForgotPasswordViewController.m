//
//  SPForgotPasswordViewController.m
//  Simperium
//
//  Created by Patrick Vink on 11/28/14.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPForgotPasswordViewController.h"
#import "SPLogger.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static SPLogLevels logLevel = SPLogLevelsInfo;

#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPForgotPasswordViewController () <UIWebViewDelegate>
    
@property (nonatomic, strong) UIWebView                 *webView;
@property (nonatomic, strong) UIActivityIndicatorView   *activityIndicator;

@end


#pragma mark ====================================================================================
#pragma mark SPForgotPasswordViewController
#pragma mark ====================================================================================

@implementation SPForgotPasswordViewController

- (void)loadView {
    
    if (!webView) {
        webView = [[UIWebView alloc] init];
        webView.delegate = self;
        self.view = webView;
    }
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.activityIndicator hidesWhenStopped];
    
    UIBarButtonItem *activityContainer = [[UIBarButtonItem alloc] initWithCustomView:self.activityIndicator];
    self.navigationItem.leftBarButtonItem = activityContainer;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(dismissAction:)];
    
    NSString *forgotPWURL = NSLocalizedString(@"Forgot Password URL", @"Using this localized string you can set your own password per language");
    
    if (![self isValidURL:forgotPWURL]) {
        SPLogInfo(@"URL for forgot password is not valid... Please use the localized string 'Forgot Password URL', to set the correct forgot password link per language");
        // Dummy link to show Simperium 404 page
        forgotPWURL = @"https://simperium.com/404.html";
    }
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:forgotPWURL]];
    [self.webView loadRequest:request];
}


#pragma mark - Helpers

- (IBAction)dismissAction:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)isValidURL:(NSString *)urlString {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    return [NSURLConnection canHandleRequest:request];
}


#pragma mark UIWebViewDelegate Methods

- (void)webViewDidStartLoad:(UIWebView *)webView {
    
    [self.activityIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    
    [self.activityIndicator stopAnimating];
}


@end
