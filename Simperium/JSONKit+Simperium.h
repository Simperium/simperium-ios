//
//  JSONKit+Simperium.h
//  Simperium
//
//  Created by Andrew Mackenzie-Ross on 9/10/2013.
//  Copyright (c) 2013 Simperium. All rights reserved.
//


// Adapters to NSJSONSerializer using the JSONKit interface
@protocol SPJSONKitAdapterSerializing <NSObject>
- (NSString *)JSONString;
@end

@interface NSArray (SPJSONKitAdapterCategories) <SPJSONKitAdapterSerializing>
@end
@interface NSDictionary (SPJSONKitAdapterCategories) <SPJSONKitAdapterSerializing>
@end

@protocol SPJSONKitAdapterDeserializing <NSObject>
- (id)objectFromJSONString;
@end

@interface NSString (SPJSONKitAdapterCategories) <SPJSONKitAdapterDeserializing>
@end
@interface NSData (SPJSONKitAdapterCategories) <SPJSONKitAdapterDeserializing>
@end
