//
//  SPCoreDataStorage.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-17.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPCoreDataStorage.h"
#import "SPManagedObject.h"
#import "NSString+Simperium.h"
#import "SPCoreDataExporter.h"
#import "SPSchema.h"
#import "DDLog.h"
#import <objc/runtime.h>

static int ddLogLevel = LOG_LEVEL_INFO;

static char const * const BucketListKey = "bucketList";

@interface SPCoreDataStorage()
-(void)addObserversForContext:(NSManagedObjectContext *)context;
@end

@implementation SPCoreDataStorage
@synthesize managedObjectContext=__managedObjectContext;
@synthesize managedObjectModel=__managedObjectModel;
@synthesize persistentStoreCoordinator=__persistentStoreCoordinator;
@synthesize delegate;

+(char const * const)bucketListKey {
    return BucketListKey;
}

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

-(id)initWithModel:(NSManagedObjectModel *)model context:(NSManagedObjectContext *)context coordinator:(NSPersistentStoreCoordinator *)coordinator
{
    if (self = [super init]) {
        stashedObjects = [[NSMutableSet setWithCapacity:3] retain];
        classMappings = [[NSMutableDictionary dictionary] retain];

        __persistentStoreCoordinator = [coordinator retain];
        __managedObjectModel = [model retain];
        __managedObjectContext = [context retain];
        
        [self addObserversForContext:context];
    }
    return self;
}

-(id)initWithSibling:(SPCoreDataStorage *)aSibling
{
    if (self = [super init]) {
        // Create an ephemeral, thread-safe context that will merge back to the sibling automatically
        sibling = aSibling;
        NSManagedObjectContext *newContext = [[NSManagedObjectContext alloc] init];
        __managedObjectContext = [newContext retain];
        [__managedObjectContext release];
        
        [__managedObjectContext setPersistentStoreCoordinator:sibling.managedObjectContext.persistentStoreCoordinator];
        
        // Simperium's context always trumps the app's local context (potentially stomping in-memory changes)
        [sibling.managedObjectContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
        [__managedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        
        // For efficiency
        [__managedObjectContext setUndoManager:nil];
        
        // An observer is expected to handle merges for otherContext when the threaded context is saved
        [[NSNotificationCenter defaultCenter] addObserver:sibling
                                                 selector:@selector(mergeChanges:)
                                                     name:NSManagedObjectContextDidSaveNotification
                                                   object:__managedObjectContext];
        
        // Be sure to copy the bucket list
        NSDictionary *dict = objc_getAssociatedObject(aSibling.managedObjectContext, BucketListKey);
        objc_setAssociatedObject(__managedObjectContext, BucketListKey, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return self;
}

-(void)dealloc
{
    objc_setAssociatedObject(__managedObjectContext, BucketListKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (sibling) {
        // If a sibling was used, then this context was ephemeral and needs to be cleaned up
        [[NSNotificationCenter defaultCenter] removeObserver:sibling name:NSManagedObjectContextDidSaveNotification object:__managedObjectContext];
        [__managedObjectContext release];
        __managedObjectContext = nil;
    }
    
    [classMappings release];
    [stashedObjects release];
    [super dealloc];
}

-(NSManagedObjectModel *)managedObjectModel {
    return __managedObjectModel;
}

-(NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    return __persistentStoreCoordinator;
}

-(NSManagedObjectContext *)managedObjectContext {
    return __managedObjectContext;
}

-(void)setBucketList:(NSDictionary *)dict {
    // Set a custom field on the context so that objects can figure out their own buckets when they wake up
    // (this could use userInfo on iOS5, but it doesn't exist on iOS4)
    objc_setAssociatedObject(__managedObjectContext, BucketListKey, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(NSArray *)exportSchemas {
    SPCoreDataExporter *exporter = [[SPCoreDataExporter alloc] init];
    NSDictionary *definitionDict = [exporter exportModel:__managedObjectModel classMappings:classMappings];
    [exporter release];
    
    DDLogInfo(@"Simperium loaded %lu entity definitions", (unsigned long)[definitionDict count]);
    
    NSUInteger numEntities = [[definitionDict allKeys] count];
    NSMutableArray *schemas = [NSMutableArray arrayWithCapacity:numEntities];
    for (NSString *entityName in [definitionDict allKeys]) {
        NSDictionary *entityDict = [definitionDict valueForKey:entityName];
        
        SPSchema *schema = [[SPSchema alloc] initWithBucketName:entityName data:entityDict];
        [schemas addObject:schema];
        [schema release];
    }
    return schemas;
}

-(id<SPStorageProvider>)threadSafeStorage {
    return [[[SPCoreDataStorage alloc] initWithSibling:self] autorelease];
}

-(id<SPDiffable>)objectForKey: (NSString *)key bucketName:(NSString *)bucketName {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:bucketName inManagedObjectContext:__managedObjectContext];
    [fetchRequest setEntity:entityDescription];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"simperiumKey == %@", key];
    [fetchRequest setPredicate:predicate];
    
    NSError *error;
    NSArray *items = [__managedObjectContext executeFetchRequest:fetchRequest error:&error];
    [fetchRequest release];
    
    if ([items count] == 0)
        return nil;
    
    return [items objectAtIndex:0];
}


-(NSArray *)objectsForKeys:(NSSet *)keys bucketName:(NSString *)bucketName
{
    return [[self faultObjectsForKeys:[keys allObjects] bucketName:bucketName] allValues];
}

-(NSArray *)objectsForBucketName:(NSString *)bucketName predicate:(NSPredicate *)predicate
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:bucketName inManagedObjectContext:__managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setReturnsObjectsAsFaults:YES];
    
    if (predicate)
        [fetchRequest setPredicate:predicate];
    
    NSError *error;
    NSArray *items = [__managedObjectContext executeFetchRequest:fetchRequest error:&error];
    [fetchRequest release];
    
    return items;
}

-(NSInteger)numObjectsForBucketName:(NSString *)bucketName predicate:(NSPredicate *)predicate
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:bucketName inManagedObjectContext:__managedObjectContext]];
    [request setIncludesSubentities:NO]; //Omit subentities. Default is YES (i.e. include subentities) 
    if (predicate)
        [request setPredicate:predicate];
    
    NSError *err;
    NSUInteger count = [__managedObjectContext countForFetchRequest:request error:&err];
    [request release];
    if(count == NSNotFound) {
        //Handle error
        return 0;
    }
    
    return count;
}
-(id)objectAtIndex:(NSUInteger)index bucketName:(NSString *)bucketName {
    // Not supported
    return nil;
}

-(void)insertObject:(id<SPDiffable>)object bucketName:(NSString *)bucketName {
    // Not supported
}

-(NSDictionary *)faultObjectsForKeys:(NSArray *)keys bucketName:(NSString *)bucketName {
    // Batch fault a bunch of objects for efficiency
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"simperiumKey IN %@", keys];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:bucketName inManagedObjectContext:__managedObjectContext];
    [fetchRequest setEntity:entityDescription];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    
    NSError *error;
    NSArray *objectArray = [__managedObjectContext executeFetchRequest:fetchRequest error:&error];
    [fetchRequest release];
    
    NSMutableDictionary *objects = [NSMutableDictionary dictionaryWithCapacity:[keys count]];
    for (SPManagedObject *object in objectArray) {
        [objects setObject:object forKey:object.simperiumKey];
    }
    return objects;
}

-(void)refaultObjects:(NSArray *)objects {
    for (SPManagedObject *object in objects) {
        [__managedObjectContext refreshObject:object mergeChanges:NO];
    }
}

-(id)insertNewObjectForBucketName:(NSString *)bucketName simperiumKey:(NSString *)key
{
	// Every object has its persistent storage managed automatically
    SPManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:bucketName
                                                     inManagedObjectContext:__managedObjectContext];
	
    object.simperiumKey = key ? key : [NSString sp_makeUUID];
    
    // Populate with member data if applicable
//	if (memberData)
//		[entity loadMemberData: memberData manager: self];
    
	return object;
}

-(void)deleteObject:(id<SPDiffable>)object
{
    SPManagedObject *managedObject = (SPManagedObject *)object;
    [managedObject.managedObjectContext deleteObject:managedObject];
}

-(void)deleteAllObjectsForBucketName:(NSString *)bucketName {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:bucketName inManagedObjectContext:__managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // No need to fault everything
    [fetchRequest setIncludesPropertyValues:NO];
    
    NSError *error;
    NSArray *items = [__managedObjectContext executeFetchRequest:fetchRequest error:&error];
    [fetchRequest release];
    
    for (NSManagedObject *managedObject in items) {
        [__managedObjectContext deleteObject:managedObject];
    }
    if (![__managedObjectContext save:&error]) {
        NSLog(@"Simperium error deleting %@ - error:%@",bucketName,error);
    }
}

-(void)validateObjectsForBucketName:(NSString *)bucketName
{
    NSEntityDescription *entity = [NSEntityDescription entityForName:bucketName inManagedObjectContext:__managedObjectContext];
    if (entity == nil) {
        //DDLogWarn(@"Simperium warning: couldn't find any instances for entity named %@", entityName);
        return;
    }
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entity];
    
    // Execute a targeted fetch to preserve faults so that only simperiumKeys are loaded in to memory
    // http://stackoverflow.com/questions/3956406/core-data-how-to-get-nsmanagedobjects-objectid-when-nsfetchrequest-returns-nsdi
    NSExpressionDescription* objectIdDesc = [[NSExpressionDescription new] autorelease];
    objectIdDesc.name = @"objectID";
    objectIdDesc.expression = [NSExpression expressionForEvaluatedObject];
    objectIdDesc.expressionResultType = NSObjectIDAttributeType;
    NSDictionary *properties = [entity propertiesByName];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = [NSArray arrayWithObjects:[properties objectForKey:@"simperiumKey"], objectIdDesc, nil];
    
    NSError *error = nil;
    NSArray *results = [__managedObjectContext executeFetchRequest:request error:&error];
    if (results == nil) {
        // Handle the error.
        NSAssert1(0, @"Simperium error: couldn't load array of entities (%@)", bucketName);
    }
    
    // Check each entity instance
    for (NSDictionary *result in results) {
        SPManagedObject *object = (SPManagedObject *)[__managedObjectContext objectWithID:[result objectForKey:@"objectID"]];
        NSString *key = [result objectForKey:@"simperiumKey"];
        // In apps like Simplenote where legacy data might exist on the device, the simperiumKey might need to
        // be set manually. Provide that opportunity here.
        if (key == nil) {
            if ([object respondsToSelector:@selector(getSimperiumKeyFromLegacyKey)]) {
                key = [object performSelector:@selector(getSimperiumKeyFromLegacyKey)];
                if (key && key.length > 0)
                    DDLogVerbose(@"Simperium local entity found without key (%@), porting legacy key: %@", bucketName, key);
            }
            
            // If it's still nil (unsynced local change in legacy system), treat it like a newly inserted object:
            // generate a UUID and mark it for sycing
            if (key == nil || key.length == 0) {
                DDLogVerbose(@"Simperium local entity found with no legacy key (created offline?); generating one now");
                key = [NSString sp_makeUUID];
            }
            object.simperiumKey = key;
            
            // The object is now managed by Simperium, so create a new ghost for it and be sure to configure its definition
            // (it's likely a legacy object that was fetched before Simperium was started)
            [self configureNewGhost:object];
            
            // The following is no longer needed; configureBucket is called in the object's awakeFromFetch as a result of
            // the object.simperiumKey assignment above
            // HOWEVER, when seeding/migrating data, the object could already have been faulted
            [object performSelector:@selector(configureBucket)];
        }
    }
    
    NSLog(@"Simperium managing %lu %@ object instances", (unsigned long)[results count], bucketName);
    
    [request release];    
}

-(BOOL)save
{
    // Standard way to save an NSManagedObjectContext
    NSError *error = nil;
    if (__managedObjectContext != nil)
    {
        @try
        {
            BOOL bChanged = [__managedObjectContext hasChanges];
            if (bChanged && ![__managedObjectContext save:&error])
            {
                NSLog(@"Critical Simperium error while saving context: %@, %@", error, [error userInfo]);
                return NO;
            }
        }
        @catch (NSException *exception)
        {
            NSLog(@"Simperium exception while saving context: %@", (id)[exception userInfo] ?: (id)[exception reason]);	
        }
    }  
    return YES;
}

-(void)setMetadata:(NSDictionary *)metadata {
    NSPersistentStore *store = [self.persistentStoreCoordinator.persistentStores objectAtIndex:0];
    [self.persistentStoreCoordinator setMetadata:metadata forPersistentStore:store];
}

-(NSDictionary *)metadata {
    NSPersistentStore *store = [self.persistentStoreCoordinator.persistentStores objectAtIndex:0];
    return [store metadata];
}

// CD specific
# pragma mark Stashing and unstashing entities
-(NSArray *)allUpdatedAndInsertedObjects
{
    NSMutableSet *unsavedEntities = [NSMutableSet setWithCapacity:3];
    
    // Add updated objects
    [unsavedEntities addObjectsFromArray:[[__managedObjectContext updatedObjects] allObjects]];
    
    // Also check for newly inserted objects
    [unsavedEntities addObjectsFromArray:[[__managedObjectContext insertedObjects] allObjects]];
    
    return [unsavedEntities allObjects];
}

-(void)stashUnsavedObjects
{
    NSArray *entitiesToStash = [self allUpdatedAndInsertedObjects];
    
    if ([entitiesToStash count] > 0) {
        DDLogVerbose(@"Simperium stashing changes for %lu entities", (unsigned long)[entitiesToStash count]);
        [stashedObjects addObjectsFromArray: entitiesToStash];
    }
}

-(void)contextDidSave:(NSNotification *)notification {
    // This bypass allows saving to be performed without triggering a sync, as is needed
    // when storing changes that come off the wire
    if (![delegate objectsShouldSync])
        return;
    
    NSSet *insertedObjects = [notification.userInfo objectForKey:NSInsertedObjectsKey];
    NSSet *updatedObjects = [notification.userInfo objectForKey:NSUpdatedObjectsKey];
    NSSet *deletedObjects = [notification.userInfo objectForKey:NSDeletedObjectsKey];
    
    // Sync all changes
    [delegate storage:self updatedObjects:updatedObjects insertedObjects:insertedObjects deletedObjects:deletedObjects];
}

-(void)contextWillSave:(NSNotification *)notification {
    // Not currently used
}

-(void)contextObjectsDidChange:(NSNotification *)notification {
    // Check for inserted objects and init them
    NSSet *insertedObjects = [notification.userInfo objectForKey:NSInsertedObjectsKey];
    
    for (NSManagedObject *insertedObject in insertedObjects) {
        if ([insertedObject isKindOfClass:[SPManagedObject class]]) {
            SPManagedObject *object = (SPManagedObject *)insertedObject;
            [self configureInsertedObject: object];
        }
    }
}

-(void)addObserversForContext:(NSManagedObjectContext *)moc {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contextDidSave:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:moc];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contextObjectsDidChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:moc];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contextWillSave:)
                                                 name:NSManagedObjectContextWillSaveNotification
                                               object:moc];
}

// Called when threaded contexts need to merge back
- (void)mergeChanges:(NSNotification*)notification 
{
    // Fault in all updated objects
    // (fixes NSFetchedResultsControllers that have predicates, see http://www.mlsite.net/blog/?p=518)
//	NSArray* updates = [[notification.userInfo objectForKey:@"updated"] allObjects];
//	for (NSInteger i = [updates count]-1; i >= 0; i--)
//	{
//		[[__managedObjectContext objectWithID:[[updates objectAtIndex:i] objectID]] willAccessValueForKey:nil];
//	}

    dispatch_sync(dispatch_get_main_queue(), ^{
        [__managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
    });
//    [__managedObjectContext performSelectorOnMainThread:@selector(mergeChangesFromContextDidSaveNotification:)
//                                     withObject:notification
//                                  waitUntilDone:YES];
}

// Standard stack

+(BOOL)isMigrationNecessary:(NSURL *)storeURL managedObjectModel:(NSManagedObjectModel *)managedObjectModel
{
    NSError *error = nil;
    
    // Determine if a migration is needed
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                              URL:storeURL
                                                                                            error:&error];

    // A migration is needed if the existing model isn't compatible with the given model
    BOOL pscCompatibile = [managedObjectModel isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata];
    return !pscCompatibile;
}

+(BOOL)newCoreDataStack:(NSString *)modelName
   managedObjectContext:(NSManagedObjectContext **)managedObjectContext
     managedObjectModel:(NSManagedObjectModel **)managedObjectModel
persistentStoreCoordinator:(NSPersistentStoreCoordinator **)persistentStoreCoordinator
{
    NSLog(@"Setting up Core Data: %@", modelName);
    //NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Simplenote" withExtension:@"momd"];
    
    NSURL *developerModelURL;
    @try {
        developerModelURL = [NSURL fileURLWithPath: [[NSBundle mainBundle]  pathForResource:modelName ofType:@"momd"]];
        *managedObjectModel = [[[NSManagedObjectModel alloc] initWithContentsOfURL:developerModelURL] autorelease];
    } @catch (NSException *e) {
        NSLog(@"Simperium error: could not find the specified model file (%@.xcdatamodeld)", modelName);
        @throw; // rethrow the exception
    }
    
    // Setup the persistent store
    //NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Simplenote.sqlite"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString *databaseFilename = [NSString stringWithFormat:@"%@.sqlite", bundleName];    
    NSString *path = [documentsDirectory stringByAppendingPathComponent:databaseFilename];
    NSURL *storeURL = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    *persistentStoreCoordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:*managedObjectModel] autorelease];
    
    // Determine if lightweight migration is going to be necessary; this will be used to notify the app in case further action is needed
    BOOL lightweightMigrationNeeded = [SPCoreDataStorage isMigrationNecessary:storeURL managedObjectModel:*managedObjectModel];
    
    // Perform automatic, lightweight migration
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
    if (![*persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error])
    {
         //TODO: this can occur the first time you launch a Simperium app after adding Simperium to it. The existing data store lacks the dynamically added members, so it must be upgraded first, and then the opening of the persistent store must be attempted again.
         
        NSLog(@"Simperium failed to perform lightweight migration; app should perform manual migration");
    }    
    
    // Setup the context
    if (persistentStoreCoordinator != nil)
    {
        *managedObjectContext = [[[NSManagedObjectContext alloc] init] autorelease];
        [*managedObjectContext setPersistentStoreCoordinator:*persistentStoreCoordinator];
        [*managedObjectContext setUndoManager:nil];
    }
        
    return lightweightMigrationNeeded;
}

// Need to perform a manual migration in a particular case. Do this according to Apple's guidelines.
- (BOOL)migrateStore:(NSURL *)storeURL sourceModel:(NSManagedObjectModel *)srcModel
    destinationModel:(NSManagedObjectModel *)dstModel
{
    NSError *error;
    NSMappingModel *mappingModel = [NSMappingModel inferredMappingModelForSourceModel:srcModel
                                                                     destinationModel:dstModel error:&error];
    if (error) {
        NSString *message = [NSString stringWithFormat:@"Inferring failed %@ [%@]",
                             [error description], ([error userInfo] ? [[error userInfo] description] : @"no user info")];
        NSLog(@"Migration failure message: %@", message);
        
        return NO;
    }
    
    NSValue *classValue = [[NSPersistentStoreCoordinator registeredStoreTypes] objectForKey:NSSQLiteStoreType];
    Class sqliteStoreClass = (Class)[classValue pointerValue];
    Class sqliteStoreMigrationManagerClass = [sqliteStoreClass migrationManagerClass];
    
    NSMigrationManager *manager = [[sqliteStoreMigrationManagerClass alloc]
                                   initWithSourceModel:srcModel destinationModel:dstModel];
    
    if (![manager migrateStoreFromURL:storeURL type:NSSQLiteStoreType
                              options:nil withMappingModel:mappingModel toDestinationURL:nil
                      destinationType:NSSQLiteStoreType destinationOptions:nil error:&error]) {
        
        NSString *message = [NSString stringWithFormat:@"Migration failed %@ [%@]",
                             [error description], ([error userInfo] ? [[error userInfo] description] : @"no user info")];
        NSLog(@"Migration failure message: %@", message);
        [manager release];
        return NO;
    }
    [manager release];
    return YES;
}

@end


// Unused code for dividing up changes per bucket (ugly)
//    // Divvy up according to buckets; this is necessary to avoid each object maintaining a reference back to its bucket, which doesn't
//    // work well with multiple Simperium instances
//    // On iOS5, bucket references on objects could work via userInfo on NSManagedObjectContext instead
//    NSMutableDictionary *bucketLists = [NSMutableDictionary dictionaryWithCapacity:5];
//
//    // This code is awful
//    for (id<SPDiffable>object in insertedObjects) {
//        NSString *bucketName = [self nameForEntityClass:[object class]];
//        NSMutableDictionary *objectLists = [bucketLists objectForKey:bucketName];
//        if (!objectLists) {
//            // Create a dict to hold all inserted, updated and deleted objects for that bucket
//            objectLists = [NSMutableDictionary dictionaryWithCapacity:3];
//            [bucketLists setObject:objectLists forKey:bucketName];
//        }
//        
//        NSMutableArray *bucketObjects = [objectLists objectForKey:@"insertedObjects"];
//        if (!bucketObjects) {
//            // Create an array in the dict
//            bucketObjects = [NSMutableArray arrayWithCapacity:3];
//            [objectLists setObject:bucketObjects forKey:@"insertedObjects"];
//        }
//        [bucketObjects addObject:object];
//    }
//
//    for (id<SPDiffable>object in updatedObjects) {
//        NSString *bucketName = [self nameForEntityClass:[object class]];
//        NSMutableDictionary *objectLists = [bucketLists objectForKey:bucketName];
//        if (!objectLists) {
//            // Create a dict to hold all inserted, updated and deleted objects for that bucket
//            objectLists = [NSMutableDictionary dictionaryWithCapacity:3];
//            [bucketLists setObject:objectLists forKey:bucketName];
//        }
//        
//        NSMutableArray *bucketObjects = [objectLists objectForKey:@"updatedObjects"];
//        if (!bucketObjects) {
//            // Create an array in the dict
//            bucketObjects = [NSMutableArray arrayWithCapacity:3];
//            [objectLists setObject:bucketObjects forKey:@"updatedObjects"];
//        }
//        [bucketObjects addObject:object];
//    }
//    
//    for (id<SPDiffable>object in deletedObjects) {
//        NSString *bucketName = [self nameForEntityClass:[object class]];
//        NSMutableDictionary *objectLists = [bucketLists objectForKey:bucketName];
//        if (!objectLists) {
//            // Create a dict to hold all inserted, updated and deleted objects for that bucket
//            objectLists = [NSMutableDictionary dictionaryWithCapacity:3];
//            [bucketLists setObject:objectLists forKey:bucketName];
//        }
//        
//        NSMutableArray *bucketObjects = [objectLists objectForKey:@"deletedObjects"];
//        if (!bucketObjects) {
//            // Create an array in the dict
//            bucketObjects = [NSMutableArray arrayWithCapacity:3];
//            [objectLists setObject:bucketObjects forKey:@"deletedObjects"];
//        }
//        [bucketObjects addObject:object];
//    }

