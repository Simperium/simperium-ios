//
//  NSFileManager+Simperium.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/15/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "NSFileManager+Simperium.h"

@implementation NSFileManager (Simperium)

+ (NSString*)userDocumentDirectory
{
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return paths[0];
}

+ (NSString *)binaryDirectory
{
	static NSString *path = nil;
	static dispatch_once_t _once;
	
    dispatch_once(&_once, ^{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *folder = NSStringFromClass([self class]);
		path = [[NSFileManager userDocumentDirectory] stringByAppendingPathComponent:folder];
		if (![fm fileExistsAtPath:path]) {
			[fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
		}
	});
	
	return path;
}

@end
