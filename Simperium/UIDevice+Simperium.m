//
//  UIDevice+Simperium.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 9/18/15.
//  Copyright © 2015 Simperium. All rights reserved.
//

#import "UIDevice+Simperium.h"

@implementation UIDevice (Simperium)

+ (BOOL)sp_isPad {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

@end
