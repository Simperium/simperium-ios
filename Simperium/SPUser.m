//
//  SPUser.m
//  Simperium
//
//  Created by Michael Johnston on 11-06-03.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SPUser.h"
#import "NSString+Simperium.h"

@implementation SPUser
@synthesize email;
@synthesize authToken;

- (id)initWithEmail:(NSString *)username token:(NSString *)token {
    if ((self = [super init])) {
        email = [username copy];
        authToken = [token copy];
    }
    return self;
}

- (NSString *)hashedEmail {
    return [NSString sp_md5StringFromData:[email dataUsingEncoding:NSUTF8StringEncoding]];
}

- (BOOL)authenticated {
    return authToken != nil && authToken.length > 0;
}

- (void)setCustomObject:(id)object forKey:(NSString *)key {
    // Associate any JSON-serializable object with a particular key
    // This will be stored on a per-app basis
}

- (id)getCustomObjectForKey:(NSString *)key {
    // Return the JSON-deserializable object associated with a particular key
    return nil;
}

@end
