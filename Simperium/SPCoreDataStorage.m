//
//  SPCoreDataStorage.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-17.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPCoreDataStorage.h"
#import "SPManagedObject+Internals.h"
#import "NSString+Simperium.h"
#import "NSConditionLock+Simperium.h"
#import "SPCoreDataExporter.h"
#import "SPSchema.h"
#import "SPThreadsafeMutableSet.h"
#import "SPLogger.h"
#import <objc/runtime.h>



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

char* const SPCoreDataBucketListKey     = "SPCoreDataBucketListKey";
NSString* const SPCoreDataWorkerContext = @"SPCoreDataWorkerContext";
static SPLogLevels logLevel             = SPLogLevelsInfo;
static NSInteger const SPWorkersDone    = 0;


#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface SPCoreDataStorage ()
@property (nonatomic, strong, readwrite) NSManagedObjectContext         *writerManagedObjectContext;
@property (nonatomic, strong, readwrite) NSManagedObjectContext         *mainManagedObjectContext;
@property (nonatomic, strong, readwrite) NSManagedObjectModel           *managedObjectModel;
@property (nonatomic, strong, readwrite) NSPersistentStoreCoordinator   *persistentStoreCoordinator;
@property (nonatomic, strong, readwrite) NSMutableDictionary            *classMappings;
@property (nonatomic, strong, readwrite) SPThreadsafeMutableSet         *remotelyDeletedKeys;
@property (nonatomic, weak,   readwrite) SPCoreDataStorage              *sibling;
@property (nonatomic, strong, readwrite) NSConditionLock                *mutex;
@property (nonatomic, strong, readwrite) NSMutableSet                   *privateStashedObjects;
- (void)addObserversForMainContext:(NSManagedObjectContext *)context;
- (void)addObserversForChildrenContext:(NSManagedObjectContext *)context;
@end

typedef void (^SPCoreDataStorageSaveCallback)(void);


#pragma mark ====================================================================================
#pragma mark SPCoreDataStorage
#pragma mark ====================================================================================

@implementation SPCoreDataStorage

- (instancetype)initWithModel:(NSManagedObjectModel *)model
                  mainContext:(NSManagedObjectContext *)mainContext
                  coordinator:(NSPersistentStoreCoordinator *)coordinator
{
    self = [super init];
    if (self) {
        // Create a writer MOC
        self.writerManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
        self.privateStashedObjects      = [NSMutableSet setWithCapacity:3];
        self.classMappings              = [NSMutableDictionary dictionary];
        self.remotelyDeletedKeys        = [SPThreadsafeMutableSet set];
        
        self.persistentStoreCoordinator = coordinator;
        self.managedObjectModel         = model;
        self.mainManagedObjectContext   = mainContext;
        
        [self.mainManagedObjectContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
        
        // Just one mutex for this Simperium stack
        self.mutex                      = [[NSConditionLock alloc] initWithCondition:SPWorkersDone];
        
        // The new writer MOC will be the only one with direct access to the persistentStoreCoordinator
        self.writerManagedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
        self.mainManagedObjectContext.parentContext = self.writerManagedObjectContext;

        [self addObserversForMainContext:self.mainManagedObjectContext];
    }
    
    return self;
}

- (instancetype)initWithSibling:(SPCoreDataStorage *)aSibling
{
    self = [super init];
    if (self) {
        self.sibling = aSibling;
        
        // Create an ephemeral, thread-safe context that will push its changes directly to the writer MOC,
        // and will also post the changes to the MainQueue
        self.mainManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
        self.mainManagedObjectContext.userInfo[SPCoreDataWorkerContext] = @(true);
        self.mainManagedObjectContext.persistentStoreCoordinator = aSibling.persistentStoreCoordinator;
        
        // Simperium's context always trumps the app's local context (potentially stomping in-memory changes)
        [self.mainManagedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        
        // For efficiency
        [self.mainManagedObjectContext setUndoManager:nil];
        
        // Keep a reference to the writerContext
        self.writerManagedObjectContext = aSibling.writerManagedObjectContext;
        
        // Shared mutex
        self.mutex = aSibling.mutex;
        
        // An observer is expected to handle merges for otherContext when the threaded context is saved
        [self addObserversForChildrenContext:self.mainManagedObjectContext];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setBucketList:(NSDictionary *)dict {
    // Associate the bucketList with the persistentStoreCoordinator:
    // Every NSManagedObject instance will be able to retrieve the appropiate SPBucket pointer
    objc_setAssociatedObject(self.persistentStoreCoordinator, SPCoreDataBucketListKey, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)exportSchemas {
    SPCoreDataExporter *exporter = [[SPCoreDataExporter alloc] init];
    NSDictionary *definitionDict = [exporter exportModel:self.managedObjectModel classMappings:self.classMappings];
    
    SPLogInfo(@"Simperium loaded %lu entity definitions", (unsigned long)[definitionDict count]);
    
    NSUInteger numEntities = [[definitionDict allKeys] count];
    NSMutableArray *schemas = [NSMutableArray arrayWithCapacity:numEntities];
    for (NSString *entityName in [definitionDict allKeys]) {
        NSDictionary *entityDict = [definitionDict valueForKey:entityName];
        
        SPSchema *schema = [[SPSchema alloc] initWithBucketName:entityName data:entityDict];
        [schemas addObject:schema];
    }
    return schemas;
}

- (id<SPStorageProvider>)threadSafeStorage {
    return [[SPCoreDataStorage alloc] initWithSibling:self];
}

- (id<SPDiffable>)objectForKey:(NSString *)key bucketName:(NSString *)bucketName {
    NSEntityDescription *entityDescription  = [NSEntityDescription entityForName:bucketName inManagedObjectContext:self.mainManagedObjectContext];
    NSPredicate *predicate                  = [NSPredicate predicateWithFormat:@"simperiumKey == %@", key];
    
    NSFetchRequest *fetchRequest            = [[NSFetchRequest alloc] init];
    fetchRequest.entity                     = entityDescription;
    fetchRequest.predicate                  = predicate;
    fetchRequest.fetchLimit                 = 1;
    
    NSError *error;
    NSArray *items = [self.mainManagedObjectContext executeFetchRequest:fetchRequest error:&error];

    return [items firstObject];
}

- (NSArray *)objectsForKeys:(NSSet *)keys bucketName:(NSString *)bucketName {
    return [[self faultObjectsForKeys:[keys allObjects] bucketName:bucketName] allValues];
}

- (NSArray *)objectsForBucketName:(NSString *)bucketName predicate:(NSPredicate *)predicate {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:bucketName inManagedObjectContext:self.mainManagedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setReturnsObjectsAsFaults:YES];
    
    if (predicate) {
        [fetchRequest setPredicate:predicate];
    }
    
    NSError *error;
    NSArray *items = [self.mainManagedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    return items;
}

- (NSArray *)objectKeysAndIdsForBucketName:(NSString *)bucketName {
    NSEntityDescription *entity = [NSEntityDescription entityForName:bucketName inManagedObjectContext:self.mainManagedObjectContext];
    if (entity == nil) {
        //SPLogWarn(@"Simperium warning: couldn't find any instances for entity named %@", entityName);
        return nil;
    }
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entity];
    
    // Execute a targeted fetch to preserve faults so that only simperiumKeys are loaded in to memory
    // http://stackoverflow.com/questions/3956406/core-data-how-to-get-nsmanagedobjects-objectid-when-nsfetchrequest-returns-nsdi
    NSExpressionDescription* objectIdDesc = [NSExpressionDescription new];
    objectIdDesc.name = @"objectID";
    objectIdDesc.expression = [NSExpression expressionForEvaluatedObject];
    objectIdDesc.expressionResultType = NSObjectIDAttributeType;
    NSDictionary *properties = [entity propertiesByName];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = [NSArray arrayWithObjects:[properties objectForKey:@"simperiumKey"], objectIdDesc, nil];
    
    NSError *error = nil;
    NSArray *results = [self.mainManagedObjectContext executeFetchRequest:request error:&error];
    if (results == nil) {
        // Handle the error.
        NSAssert1(0, @"Simperium error: couldn't load array of entities (%@)", bucketName);
    }
    
    return results;
}

- (NSArray *)objectKeysForBucketName:(NSString *)bucketName {
    NSArray *results = [self objectKeysAndIdsForBucketName:bucketName];
    
    NSMutableArray *objectKeys = [NSMutableArray arrayWithCapacity:[results count]];
    for (NSDictionary *result in results) {
        NSString *key = [result objectForKey:@"simperiumKey"];
        [objectKeys addObject:key];
    }
    
    return objectKeys;
}

- (NSInteger)numObjectsForBucketName:(NSString *)bucketName predicate:(NSPredicate *)predicate {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:bucketName inManagedObjectContext:self.mainManagedObjectContext]];
    [request setIncludesSubentities:NO]; //Omit subentities. Default is YES (i.e. include subentities) 
    if (predicate) {
        [request setPredicate:predicate];
    }
    
    NSError *err;
    NSUInteger count = [self.mainManagedObjectContext countForFetchRequest:request error:&err];
    if (count == NSNotFound) {
        //Handle error
        return 0;
    }
    
    return count;
}

- (id)objectAtIndex:(NSUInteger)index bucketName:(NSString *)bucketName {
    // Not supported
    return nil;
}

- (void)insertObject:(id<SPDiffable>)object bucketName:(NSString *)bucketName {
    // Not supported
}

- (NSDictionary *)faultObjectsForKeys:(NSArray *)keys bucketName:(NSString *)bucketName {
    // Batch fault a bunch of objects for efficiency
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"simperiumKey IN %@", keys];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:bucketName inManagedObjectContext:self.mainManagedObjectContext];
    [fetchRequest setEntity:entityDescription];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    
    NSError *error;
    NSArray *objectArray = [self.mainManagedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    NSMutableDictionary *objects = [NSMutableDictionary dictionaryWithCapacity:[keys count]];
    for (SPManagedObject *object in objectArray) {
        [objects setObject:object forKey:object.simperiumKey];
    }
    return objects;
}

- (void)refaultObjects:(NSArray *)objects {
    for (SPManagedObject *object in objects) {
        [self.mainManagedObjectContext refreshObject:object mergeChanges:NO];
    }
}

- (id)insertNewObjectForBucketName:(NSString *)bucketName simperiumKey:(NSString *)key {
    // Every object has its persistent storage managed automatically
    SPManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:bucketName
                                                            inManagedObjectContext:self.mainManagedObjectContext];
    
    object.simperiumKey = key ?: [NSString sp_makeUUID];
    
    return object;
}

- (void)deleteObject:(id<SPDiffable>)object {
    SPManagedObject *managedObject = (SPManagedObject *)object;
    [managedObject.managedObjectContext deleteObject:managedObject];
    
    // NOTE:
    // 'mergeChangesFromContextDidSaveNotification' calls 'deleteObject' in the receiver context. As a result,
    // remote deletions will be posted as local deletions. Let's prevent that!
    if (self.sibling) {
        [self.sibling.remotelyDeletedKeys addObject:managedObject.namespacedSimperiumKey];
    }
}

- (void)deleteAllObjectsForBucketName:(NSString *)bucketName {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:bucketName inManagedObjectContext:self.mainManagedObjectContext];
    [fetchRequest setEntity:entity];
    
    // No need to fault everything
    [fetchRequest setIncludesPropertyValues:NO];
    
    NSError *error;
    NSArray *items = [self.mainManagedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    for (NSManagedObject *managedObject in items) {
        [self.mainManagedObjectContext deleteObject:managedObject];
    }
    
    if (![self.mainManagedObjectContext save:&error]) {
        NSLog(@"Simperium error deleting %@ - error:%@",bucketName,error);
    }
}

- (void)validateObjectsForBucketName:(NSString *)bucketName {
    NSArray *results = [self objectKeysAndIdsForBucketName:bucketName];
    
    // Check each entity instance
    for (NSDictionary *result in results) {
        SPManagedObject *object = (SPManagedObject *)[self.mainManagedObjectContext objectWithID:result[@"objectID"]];
        NSString *key = [result objectForKey:@"simperiumKey"];
        // In apps like Simplenote where legacy data might exist on the device, the simperiumKey might need to
        // be set manually. Provide that opportunity here.
        if (key == nil) {
            if ([object respondsToSelector:@selector(getSimperiumKeyFromLegacyKey)]) {
                key = [object performSelector:@selector(getSimperiumKeyFromLegacyKey)];
                if (key && key.length > 0)
                    SPLogVerbose(@"Simperium local entity found without key (%@), porting legacy key: %@", bucketName, key);
            }
            
            // If it's still nil (unsynced local change in legacy system), treat it like a newly inserted object:
            // generate a UUID and mark it for sycing
            if (key == nil || key.length == 0) {
                SPLogVerbose(@"Simperium local entity found with no legacy key (created offline?); generating one now");
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
}

- (void)commitPendingOperations:(void (^)())completion {
    NSParameterAssert(completion);
    
    // Let's make sure that pending blocks dispatched to the writer's queue are ready
    [self.writerManagedObjectContext performBlock:completion];
}

- (BOOL)save {
    // Standard way to save an NSManagedObjectContext
    NSError *error = nil;
    if (self.mainManagedObjectContext != nil) {
        @try {
            BOOL bChanged = [self.mainManagedObjectContext hasChanges];
            if (bChanged && ![self.mainManagedObjectContext save:&error]) {
                NSLog(@"Critical Simperium error while saving context: %@, %@", error, [error userInfo]);
                return NO;
            }
        } @catch (NSException *exception) {
            NSLog(@"Simperium exception while saving context: %@", (id)[exception userInfo] ?: (id)[exception reason]);
        }
    }  
    return YES;
}


#pragma mark - Public Properties

- (void)setMetadata:(NSDictionary *)metadata {
    NSPersistentStore *store = [self.persistentStoreCoordinator.persistentStores firstObject];
    [self.persistentStoreCoordinator setMetadata:metadata forPersistentStore:store];
}

- (NSDictionary *)metadata {
    NSPersistentStore *store = [self.persistentStoreCoordinator.persistentStores firstObject];
    return [store metadata];
}

- (NSSet *)stashedObjects {
    return [self.privateStashedObjects copy];
}


#pragma mark - Stashing and unstashing entities

- (NSArray *)allUpdatedAndInsertedObjects {
    NSMutableSet *unsavedEntities = [NSMutableSet setWithCapacity:3];
    
    // Add updated objects
    [unsavedEntities addObjectsFromArray:[[self.mainManagedObjectContext updatedObjects] allObjects]];
    
    // Also check for newly inserted objects
    [unsavedEntities addObjectsFromArray:[[self.mainManagedObjectContext insertedObjects] allObjects]];
    
    return [unsavedEntities allObjects];
}

- (void)stashUnsavedObjects {
    NSArray *entitiesToStash = [self allUpdatedAndInsertedObjects];
    
    if (entitiesToStash.count > 0) {
        SPLogVerbose(@"Simperium stashing changes for %lu entities", (unsigned long)[entitiesToStash count]);
        [self.privateStashedObjects addObjectsFromArray:entitiesToStash];
    }
}

- (void)unstashUnsavedObjects {
    [self.privateStashedObjects removeAllObjects];
}

- (void)unloadAllObjects {
    [self.privateStashedObjects removeAllObjects];
}


#pragma mark - Temporary ID Helpers

- (void)obtainPermanentIDsForInsertedObjectsInContext:(NSManagedObjectContext *)context {
    NSParameterAssert(context);
    NSMutableSet *temporaryObjects = [NSMutableSet set];
    
    for (NSManagedObject *mo in context.insertedObjects) {
        if (mo.objectID.isTemporaryID) {
            [temporaryObjects addObject:mo];
        }
    }
    
    if (temporaryObjects.count == 0) {
        return;
    }
    
    // Obtain permanentID's for newly inserted objects
    NSError *error = nil;
    if (![context obtainPermanentIDsForObjects:temporaryObjects.allObjects error:&error]) {
        SPLogVerbose(@"Unable to obtain permanent IDs for objects newly inserted into the main context: %@", error);
    }
}


#pragma mark - Main MOC Notification Handlers

- (void)mainContextWillSave:(NSNotification *)notification {
    
    // Obtain Permanent ID's!
    NSManagedObjectContext *mainContext = (NSManagedObjectContext *)notification.object;
    [self obtainPermanentIDsForInsertedObjectsInContext:mainContext];
    
    // Initialize the inserted object's simperiumKey. If needed
    if (!self.delaysNewObjectsInitialization) {
        return;
    }
    
    [self configureInsertedObjects:mainContext.insertedObjects];
}

- (void)mainContextDidSave:(NSNotification *)notification {
    // Expose the affected objects via the public properties
    NSDictionary *userInfo  = notification.userInfo;
    NSSet *deletedObjects   = [self filterRemotelyDeletedObjects:userInfo[NSDeletedObjectsKey]];
    
    [self.delegate storageWillSave:self deletedObjects:deletedObjects];
    
    // Save the writerMOC's changes
    [self saveWriterContextWithCallback:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate storageDidSave:self insertedObjects:userInfo[NSInsertedObjectsKey] updatedObjects:userInfo[NSUpdatedObjectsKey]];
        });
    }];
}

- (void)mainContextObjectsDidChange:(NSNotification *)notification {
    // Initialize the inserted object's simperiumKey. If needed
    if (self.delaysNewObjectsInitialization) {
        return;
    }
    
    NSSet *insertedObjects = [notification.userInfo objectForKey:NSInsertedObjectsKey];
    [self configureInsertedObjects:insertedObjects];

}

- (void)addObserversForMainContext:(NSManagedObjectContext *)moc {
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(mainContextWillSave:)           name:NSManagedObjectContextWillSaveNotification         object:moc];
    [nc addObserver:self selector:@selector(mainContextDidSave:)            name:NSManagedObjectContextDidSaveNotification          object:moc];
    [nc addObserver:self selector:@selector(mainContextObjectsDidChange:)   name:NSManagedObjectContextObjectsDidChangeNotification object:moc];
}


#pragma mark - Children MOC Notification Handlers

- (void)childrenContextWillSave:(NSNotification*)notification {

    // Obtain Permanent ID's!
    NSManagedObjectContext *childrenContext = (NSManagedObjectContext *)notification.object;
    [self obtainPermanentIDsForInsertedObjectsInContext:childrenContext];
    
    // Get the deleted ManagedObject ID's
    NSMutableSet *workerDeletedIds = [NSMutableSet set];
    for (NSManagedObject *object in childrenContext.deletedObjects) {
        [workerDeletedIds addObject:object.objectID];
    }
    
    if (workerDeletedIds.count == 0) {
        return;
    }
    
    // NOTE:
    // Deleting an entity in a Children MOC, while there was a faulted reference in the MainMOC, might trigger a NSObjectInaccessibleException (#436).
    // Workaround: we'll make sure the objects are actually loaded into the WriterMOC. This will effectively prevent an exception,
    // and the object will get removed as soon as the DidSave note is merged.

    [self.writerManagedObjectContext performBlockAndWait:^{
        for (NSManagedObjectID *objectID in workerDeletedIds) {
            NSManagedObject *writerMO = [self.writerManagedObjectContext existingObjectWithID:objectID error:nil];
            if (writerMO.isFault) {
                [writerMO willAccessValueForKey:nil];
            }
        }
    }];
}

- (void)childrenContextDidSave:(NSNotification*)notification {
    //  NOTE:
    //  On OSX Yosemite we're observing scenarios in which a NSManagedObject instance is updated in a worker MOC,
    //  and yet, it doesn't get refreshed on the mainMOC, even after merging the changes.
    //  This doesn't happen in iOS, but as a safety measure, let's run this snippet anyways.

    NSManagedObjectContext *writerMOC = self.writerManagedObjectContext;
    [writerMOC performBlockAndWait:^{
        [writerMOC mergeChangesFromContextDidSaveNotification:notification];
    }];

    //  NOTE II:
    //  Setting the mainMOC as the childrenMOC's parent will trigger 'mainMOC hasChanges' flag.
    //  Which, in turn, can cause changes retrieved from the backend to get posted as local changes.
    //  Let's, instead, merge the changes into the mainMOC. This will NOT trigger main MOC's hasChanges flag.

    NSManagedObjectContext* mainMOC = self.sibling.mainManagedObjectContext;
    [mainMOC performBlockAndWait:^{
        
        // Fault in all updated objects
        // (fixes NSFetchedResultsControllers that have predicates, see http://www.mlsite.net/blog/?p=518)
        NSArray* updated = [notification.userInfo[NSUpdatedObjectsKey] allObjects];
        for (NSManagedObject* childMO in updated) {
            
            // Do not use 'objectWithId': might return an object that already got deleted
            NSManagedObject* localMO = [mainMOC existingObjectWithID:childMO.objectID error:nil];
            if (localMO.isFault) {
                [localMO willAccessValueForKey:nil];
            }
        }
        
        // Proceed with the regular merge. This should trigger a contextDidChange note
        [mainMOC mergeChangesFromContextDidSaveNotification:notification];
    }];
}

- (void)addObserversForChildrenContext:(NSManagedObjectContext *)context {
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(childrenContextWillSave:) name:NSManagedObjectContextWillSaveNotification   object:context];
    [nc addObserver:self selector:@selector(childrenContextDidSave:)  name:NSManagedObjectContextDidSaveNotification    object:context];
}


#pragma mark - Delegate Helpers

- (NSSet *)filterRemotelyDeletedObjects:(NSSet *)deletedObjects {
    NSMutableSet *locallyDeleted = [NSMutableSet set];
    for (SPManagedObject* mainMO in deletedObjects) {
        if ([mainMO isKindOfClass:[SPManagedObject class]] == NO) {
            continue;
        }
        if ([self.remotelyDeletedKeys containsObject:mainMO.namespacedSimperiumKey] == NO) {
            [locallyDeleted addObject:mainMO];
        } else {
            [self.remotelyDeletedKeys removeObject:mainMO.namespacedSimperiumKey];
        }
    }
    
    return locallyDeleted;
}


#pragma mark - Writer MOC Helpers

- (void)saveWriterContextWithCallback:(SPCoreDataStorageSaveCallback)callback {
    [self.writerManagedObjectContext performBlock:^{
        @try {
            NSError *error = nil;
            if ([self.writerManagedObjectContext hasChanges] && ![self.writerManagedObjectContext save:&error]) {
                NSLog(@"Critical Simperium error while persisting writer context's changes: %@, %@", error, error.userInfo);
            }
        } @catch (NSException *exception) {
            NSLog(@"Simperium exception while persisting writer context's changes: %@", exception.userInfo ? : exception.reason);
        }
        
        if (callback) {
            callback();
        }
    }];
}


#pragma mark - Synchronization

- (void)performSafeBlockAndWait:(void (^)())block {
    NSAssert([NSThread isMainThread] == false,  @"It is not recommended to use this method on the main thread");
    NSAssert(self.sibling != nil,               @"Please, use the performBlock primitives on threadsafe storage instances");
    NSParameterAssert(block);
    
    [self.mutex sp_increaseCondition];
    block();
    [self.mutex sp_decreaseCondition];
}

- (void)performCriticalBlockAndWait:(void (^)())block {
    NSAssert([NSThread isMainThread] == false,  @"It is not recommended to use this method on the main thread");
    NSAssert(self.sibling != nil,               @"Please, use the performBlock primitives on threadsafe storage instances");
    NSParameterAssert(block);
    
    [self.mutex lockWhenCondition:SPWorkersDone];
    block();
    [self.mutex unlock];
}


#pragma mark - Standard stack

+ (BOOL)isMigrationNecessary:(NSURL *)storeURL managedObjectModel:(NSManagedObjectModel *)managedObjectModel {
    NSError *error = nil;
    
    // Determine if a migration is needed
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                              URL:storeURL
                                                                                            error:&error];

    // A migration is needed if the existing model isn't compatible with the given model
    BOOL pscCompatibile = [managedObjectModel isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata];
    return !pscCompatibile;
}

+ (BOOL)newCoreDataStack:(NSString *)modelName
             mainContext:(NSManagedObjectContext **)mainContext
                   model:(NSManagedObjectModel **)model
             coordinator:(NSPersistentStoreCoordinator **)coordinator
{
    SPLogVerbose(@"Setting up Core Data: %@", modelName);
    NSURL *developerModelURL = nil;;
    
    @try {
        developerModelURL = [NSURL fileURLWithPath: [[NSBundle mainBundle]  pathForResource:modelName ofType:@"momd"]];
        *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:developerModelURL];
    } @catch (NSException *e) {
        NSLog(@"Simperium error: could not find the specified model file (%@.xcdatamodeld)", modelName);
        @throw; // rethrow the exception
    }
    
    // Setup the persistent store
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString *databaseFilename = [NSString stringWithFormat:@"%@.sqlite", bundleName];    
    NSString *path = [documentsDirectory stringByAppendingPathComponent:databaseFilename];
    NSURL *storeURL = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:*model];
    
    // Determine if lightweight migration is going to be necessary; this will be used to notify the app in case further action is needed
    BOOL lightweightMigrationNeeded = [SPCoreDataStorage isMigrationNecessary:storeURL managedObjectModel:*model];
    
    // Perform automatic, lightweight migration
    NSDictionary *options = @{
        NSMigratePersistentStoresAutomaticallyOption : @(YES),
        NSInferMappingModelAutomaticallyOption : @(YES)
    };
    
    if (![*coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error])
    {
        // TODO: this can occur the first time you launch a Simperium app after adding Simperium to it.
        // The existing data store lacks the dynamically added members, so it must be upgraded first, and then the
        // opening of the persistent store must be attempted again.
         
        NSLog(@"Simperium failed to perform lightweight migration; app should perform manual migration");
    }    
    
    // Setup the context
    if (mainContext != nil)
    {
        *mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [*mainContext setUndoManager:nil];
    }
        
    return lightweightMigrationNeeded;
}

@end
