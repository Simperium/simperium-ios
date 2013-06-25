//
//  UIImage+Simperium.h
//  Simperium
//
//  Created by Michael Johnston on 11-10-18.
//  Copyright 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIImage.h>

@interface UIImage (NSCoding)
- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;
@end
