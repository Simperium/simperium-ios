//
//  SPWebViewController.m
//  Simperium
//
//  Created by Patrick Vink on 11/28/14.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPWebViewController.h"
#import "SPLogger.h"



#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPWebViewController () <UIWebViewDelegate>
@property (nonatomic, strong) NSURL                     *targetURL;
@property (nonatomic, strong) UIWebView                 *webView;
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
    
    self.webView            = [[UIWebView alloc] init];
    self.webView.delegate   = self;
    self.view               = self.webView;
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


#pragma mark - Helpers

- (IBAction)dismissAction:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark UIWebViewDelegate Methods

- (void)webViewDidStartLoad:(UIWebView *)webView {
    
    [self.activityIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    
    [self.activityIndicator stopAnimating];
}


@end
