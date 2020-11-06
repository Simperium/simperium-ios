//
//  SPPersistentMutableDictionary.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 9/12/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>



#pragma mark ====================================================================================
#pragma mark SPPersistentMutableDictionary
#pragma mark ====================================================================================

@interface SPPersistentMutableDictionary : NSObject

/// The Dictionary's Label is used to define the Persistent Store identifier. Different labels will map to different persistent databases.
///
@property (nonatomic, strong, readonly) NSString *label;

/// Specifies the Supported Types
/// - Note: All classes specified here must conform to NSSecureCoding
///
@property (nonatomic, strong, readwrite) NSSet<Class> *supportedObjectTypes;

/// Indicates if the stored `Supported Object Types` should be required to conform to NSCoding. Defaults to YES
/// - Important: Only used for Unit Testing purposes!
///
@property (nonatomic, assign, readwrite) BOOL requiringSecureCoding;


/// Returns the total number of stored entities
///
- (NSInteger)count;

/// Indicates if there's an object associated ot the specified Key
///
- (BOOL)containsObjectForKey:(id)aKey;

/// Returns an object associated to the specified Key. Note that the resulting Object Type will be constrained by the `supportedObjectTypes` collection
///
- (id)objectForKey:(NSString*)aKey;

/// Stores the specified Object. Please note that the Object's Type must be specified by the `supportedObjectTypes` collection
///
- (void)setObject:(id)anObject forKey:(NSString*)aKey;

/// Persists the internal stack
///
- (BOOL)save;

- (NSArray*)allKeys;
- (NSArray*)allValues;

- (void)removeObjectForKey:(id)aKey;
- (void)removeAllObjects;

+ (instancetype)loadDictionaryWithLabel:(NSString *)label;

@end
