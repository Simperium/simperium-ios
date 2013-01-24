//
//  SPReferenceManager.h
//  Simperium
//
//  Created by Michael Johnston on 2012-08-22.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SPStorageProvider.h"

@interface SPReferenceManager : NSObject {
    NSMutableDictionary *pendingReferences;
}

@property (nonatomic, retain) NSMutableDictionary *pendingReferences;

-(void)addPendingReferenceToKey:(NSString *)key fromKey:(NSString *)fromKey bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName;
-(void)resolvePendingReferencesToKey:(NSString *)toKey bucketName:(NSString *)bucketName storage:(id<SPStorageProvider>)storage;
-(void)reset;

@end
