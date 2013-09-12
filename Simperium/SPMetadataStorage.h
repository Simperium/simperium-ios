//
//  SPMetadataStorage.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 9/12/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface SPMetadataStorage : NSObject

@property (nonatomic, strong, readonly) NSString *label;

- (id)initWithLabel:(NSString *)label;

- (NSInteger)count;

- (id)objectForKey:(NSString*)aKey;
- (void)setObject:(id)anObject forKey:(NSString*)aKey;

- (NSArray*)allKeys;
- (NSArray*)allValues;

- (void)removeObjectForKey:(id)aKey;
- (void)removeAllObjects;

@end
