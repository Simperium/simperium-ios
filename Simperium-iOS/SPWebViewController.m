//
//  SPWebViewController.m
//  Simperium
//
//  Created by Patrick Vink on 11/28/14.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPWebViewController.h"
#import "UIDevice+Simperium.h"
#import <WebKit/WebKit.h>



#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPWebViewController () <WKNavigationDelegate>
@property (nonatomic, strong) NSURL                     *targetURL;
@property (nonatomic, strong) WKWebView                 *webView;
@property (nonatomic, strong) UIActivityIndicatorView   *activityIndicator;
@end


#pragma mark ====================================================================================
#pragma mark SPWebViewController
#pragma mark ====================================================================================

@implementation SPWebViewController

- (instancetype)initWithURL:(NSString *)url {
    
    NSParameterAssert(url);
    
    self = [super init];
    if (self) {
        self.targetURL = [NSURL URLWithString:url];
    }
    
    return self;
}

- (void)loadView {
    
    self.webView = [WKWebView new];
    self.webView.navigationDelegate = self;
    self.view = self.webView;
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

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.targetURL];
    [self.webView loadRequest:request];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return [UIDevice sp_isPad] ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}


#pragma mark - Helpers

- (IBAction)dismissAction:(id)sender {

    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark UIWebViewDelegate Methods

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [self.activityIndicator startAnimating];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self.activityIndicator stopAnimating];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self.activityIndicator stopAnimating];
}

@end
