//
//  SPStorage.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-17.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPDiffable.h"

@interface SPStorage : NSObject
- (void)stopManagingObjectWithKey:(NSString *)key;
- (void)configureInsertedObject:(id<SPDiffable>)object;
- (void)configureInsertedObjects:(NSSet *)insertedObjects;
- (void)configureNewGhost:(id<SPDiffable>)object;
@end
