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

// Note: Readonly for now!
@property (nonatomic, strong, readonly) NSDictionary *dict;
@property (nonatomic, strong) SPGhost *ghost;
@property (nonatomic, copy) NSString *ghostData;
@property (nonatomic, copy) NSString *simperiumKey;
@property (nonatomic, copy) NSString *version;

- (instancetype)initWithDictionary:(NSMutableDictionary *)dictionary;

@end
