//
//  SPTOSViewController.m
//  Simperium
//
//  Created by Tom Witkin on 8/27/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPTOSViewController.h"

@interface SPTOSViewController ()

@end

@implementation SPTOSViewController

- (void)loadView {
    
    if (!webView) {
        webView = [[UIWebView alloc] init];
        webView.delegate = self;
        self.view = webView;
    }
}

- (void)dismissAction:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [activityIndicator hidesWhenStopped];
    UIBarButtonItem *activityContainer = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
    self.navigationItem.leftBarButtonItem = activityContainer;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissAction:)];
    
    NSString *termsURL = NSLocalizedString(@"TOS URL", @"Using this localized string you can set your own TOS per language");
    
    if (![self isValidURL:termsURL]) {
        // Show default Simperium TOS
        termsURL = @"http://simperium.com/tos/";
    }
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:termsURL]];
    [webView loadRequest:request];
}

- (BOOL)isValidURL:(NSString *)urlString{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    return [NSURLConnection canHandleRequest:request];
}

#pragma mark UIWebViewDelegate Methods

- (void)webViewDidStartLoad:(UIWebView *)webView {
    
    [activityIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    
    [activityIndicator stopAnimating];
}


@end
