//
//  UIViewController.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/27/15.
//  Copyright © 2015 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIViewController (Simperium)

- (BOOL)sp_isViewAttached;
- (UIViewController *)sp_leafViewController;

@end
