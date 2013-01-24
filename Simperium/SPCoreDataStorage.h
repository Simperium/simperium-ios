//
//  SPCoreDataStorage.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-17.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPStorage.h"
#import "SPStorageObserver.h"
#import "SPStorageProvider.h"

@interface SPCoreDataStorage : SPStorage<SPStorageProvider> {
    id<SPStorageObserver> delegate;
    SPCoreDataStorage *sibling;
    NSMutableDictionary *classMappings;
}

@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, assign) id<SPStorageObserver>delegate;

+(char const * const)bucketListKey;
+(BOOL)newCoreDataStack:(NSString *)modelName
   managedObjectContext:(NSManagedObjectContext **)managedObjectContext
     managedObjectModel:(NSManagedObjectModel **)managedObjectModel
persistentStoreCoordinator:(NSPersistentStoreCoordinator **)persistentStoreCoordinator;

-(id)initWithModel:(NSManagedObjectModel *)model context:(NSManagedObjectContext *)context coordinator:(NSPersistentStoreCoordinator *)coordinator;

-(NSArray *)exportSchemas;
-(void)setBucketList:(NSDictionary *)dict;

@end
