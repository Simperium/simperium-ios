//
//  UIViewController.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/27/15.
//  Copyright © 2015 Simperium. All rights reserved.
//

#import "UIViewController+Simperium.h"

@implementation UIViewController (Simperium)

- (BOOL)sp_isViewOnscreen
{
    BOOL visibleAsRoot          = self.view.window.rootViewController == self;
    BOOL visibleAsTopOnStack    = self.navigationController.topViewController == self;
    BOOL visibleAsPresented     = [self.view.window.rootViewController sp_leafViewController] == self;
    
    return visibleAsRoot || visibleAsTopOnStack || visibleAsPresented;
}

- (UIViewController *)sp_leafViewController
{
    UIViewController *leafViewController = self;
    while (leafViewController.presentedViewController) {
        leafViewController = leafViewController.presentedViewController;
    }
    
    return leafViewController;
}

@end
