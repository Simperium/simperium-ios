//
//  SPGhost.m
//  Simperium
//
//  Created by Michael Johnston on 11-03-08.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SPGhost.h"


@implementation SPGhost
@synthesize key, memberData, version;
@synthesize needsSave;

- (id)initFromDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        self.key        = dict[@"key"];
        self.memberData = dict[@"obj"];
        self.version    = dict[@"version"];
        
        // Make sure it's not marked dirty when initializing in this way, since ghosts are loaded
        // through this method on launch
        needsSave = NO;
    }
    
	return self;
}

- (id)initWithKey:(NSString *)k memberData:(NSMutableDictionary *)data {
	if ((self = [super init])) {
		self.key = k;
		self.memberData = data;
	}
	return self;
}

- (id)copyWithZone: (NSZone *) zone {
    SPGhost *newGhost = [[[self class] allocWithZone:zone] init];
	newGhost.key = [self key];
	newGhost.memberData = [self memberData];
    newGhost.version = [self version];
    return newGhost;
}

- (id)mutableCopyWithZone: (NSZone *) zone {
    SPGhost *newGhost = [[[self class] allocWithZone:zone] init];	
	newGhost.key = [self key];
    newGhost.version = [self version];
	
	NSMutableDictionary *memberDataCopy = [[self memberData] mutableCopyWithZone:zone];
	newGhost.memberData = memberDataCopy;
	return newGhost;
}

- (void)setMemberData:(NSMutableDictionary *)newMemberData {
    memberData = [newMemberData mutableCopy];
    needsSave = YES;
}

- (void)setKey:(NSString *)newKey {
    key = [newKey copy];
    needsSave = YES;
}

- (void)setVersion:(NSString *)newVersion {
    version = [newVersion copy];
    needsSave = YES;
}

- (NSDictionary *)dictionary {
	if (version == nil) {
		return @{
             @"key"     : self.key,
             @"obj"     : self.memberData,
         };
	} else {
		return @{
            @"key"     : self.key,
            @"version" : self.version,
            @"obj"     : self.memberData,
        };
    }
}

@end
