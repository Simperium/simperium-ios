//
//  SPObject.h
//  Simperium
//
//  Created by Michael Johnston on 12-04-11.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPDiffable.h"

@interface SPObject : NSObject<SPDiffable>

@property (nonatomic, strong) SPGhost *ghost;
@property (nonatomic, copy) NSString *ghostData;
@property (nonatomic, copy) NSString *simperiumKey;
@property (nonatomic, copy, readonly) NSString *version;
@property (nonatomic, copy, readonly) NSDictionary *dictionary;

- (instancetype)initWithDictionary:(NSMutableDictionary *)dictionary;

@end
