//
//  UIImage+Simperium.m
//  Simperium
//
//  Created by Michael Johnston on 11-10-18.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "UIImage+Simperium.h"

@interface FIXCATEGORYBUGIMAGE : NSObject;
@end
@implementation FIXCATEGORYBUGIMAGE;
@end

@implementation UIImage (NSCoding)
- (id)initWithCoder:(NSCoder *)decoder {
    NSData *pngData = [decoder decodeObjectForKey:@"PNGRepresentation"];
    self = [[UIImage alloc] initWithData:pngData];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:UIImagePNGRepresentation(self) forKey:@"PNGRepresentation"];
}
@end