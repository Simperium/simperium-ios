//
//  NSFileManager+Simperium.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/15/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "NSFileManager+Simperium.h"

@implementation NSFileManager (Simperium)

+ (NSString*)sp_userDocumentDirectory
{
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return paths[0];
}

@end
