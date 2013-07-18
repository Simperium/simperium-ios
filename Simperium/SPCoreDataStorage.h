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
    id<SPStorageObserver> __weak	delegate;
    SPCoreDataStorage				*sibling;
    NSMutableDictionary				*classMappings;
}

@property (nonatomic, strong,  readonly) NSManagedObjectContext			*managedObjectContext;
@property (nonatomic, strong,  readonly) NSManagedObjectModel			*managedObjectModel;
@property (nonatomic, strong,  readonly) NSPersistentStoreCoordinator	*persistentStoreCoordinator;
@property (nonatomic, weak,	  readwrite) id<SPStorageObserver>			delegate;

+(BOOL)newCoreDataStack:(NSString *)modelName
   managedObjectContext:(NSManagedObjectContext **)managedObjectContext
     managedObjectModel:(NSManagedObjectModel **)managedObjectModel
persistentStoreCoordinator:(NSPersistentStoreCoordinator **)persistentStoreCoordinator;

-(id)initWithModel:(NSManagedObjectModel *)model context:(NSManagedObjectContext *)context coordinator:(NSPersistentStoreCoordinator *)coordinator;

-(NSArray *)exportSchemas;
-(void)setBucketList:(NSDictionary *)dict;

@end
