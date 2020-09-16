//
//  NSURLResponse+Simperium.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/21/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "NSURLResponse+Simperium.h"

@implementation NSURLResponse (Simperium)

- (NSInteger)sp_statusCode {
    if ([self isKindOfClass:[NSHTTPURLResponse class]] == false) {
        return 501;
    }

    return [(NSHTTPURLResponse *)self statusCode];
}

@end
