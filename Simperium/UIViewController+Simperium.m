//
//  UIViewController.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/27/15.
//  Copyright © 2015 Simperium. All rights reserved.
//

#import "UIViewController+Simperium.h"

@implementation UIViewController (Simperium)

- (BOOL)sp_isViewAttached
{
    return self.view.window != nil;
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
