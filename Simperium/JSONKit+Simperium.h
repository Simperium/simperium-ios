//
//  JSONKit+Simperium.h
//  Simperium
//
//  Created by Andrew Mackenzie-Ross on 9/10/2013.
//  Copyright (c) 2013 Simperium. All rights reserved.
//


// Adapters to NSJSONSerializer using the JSONKit interface
@interface NSArray (SPJSONKitAdapterCategories)
- (NSString *)JSONString;
@end

@interface NSDictionary (SPJSONKitAdapterCategories)
- (NSString *)JSONString;
@end

@interface NSString (SPJSONKitAdapterCategories)
- (id)objectFromJSONString;
@end

@interface NSData (SPJSONKitAdapterCategories)
- (id)objectFromJSONString;
@end
