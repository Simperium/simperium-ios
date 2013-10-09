//
//  SPBucket.m
//  Simperium
//
//  Created by Michael Johnston on 12-04-12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPBucket.h"
#import "SPDiffable.h"
#import "SPDiffer.h"
#import "SPStorage.h"
#import "SPSchema.h"
#import "SPNetworkInterface.h"
#import "SPChangeProcessor.h"
#import "SPIndexProcessor.h"
#import "DDLog.h"
#import "SPGhost.h"
#import "JSONKit+Simperium.h"
#import "SPRelationshipResolver.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface SPBucket()
@end

@implementation SPBucket
@synthesize delegate;
@synthesize name;
@synthesize notifyWhileIndexing;
@synthesize instanceLabel;
@synthesize storage;
@synthesize differ;
@synthesize network;
@synthesize relationshipResolver;
@synthesize changeProcessor;
@synthesize indexProcessor;
@synthesize processorQueue;
@synthesize lastChangeSignature;

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

- (id)initWithSchema:(SPSchema *)aSchema storage:(id<SPStorageProvider>)aStorage networkInterface:(id<SPNetworkInterface>)netInterface
relationshipResolver:(SPRelationshipResolver *)resolver label:(NSString *)label
{
    if ((self = [super init])) {
        name = [aSchema.bucketName copy];
        self.storage = aStorage;
        self.network = netInterface;
        self.relationshipResolver = resolver;

        SPDiffer *aDiffer = [[SPDiffer alloc] initWithSchema:aSchema];
        self.differ = aDiffer;

        // Label is used to support multiple simperium instances (e.g. unit testing)
        self.instanceLabel = [NSString stringWithFormat:@"%@%@", self.name, label];

        SPChangeProcessor *cp = [[SPChangeProcessor alloc] initWithLabel:self.instanceLabel];
        self.changeProcessor = cp;

        SPIndexProcessor *ip = [[SPIndexProcessor alloc] init];
        self.indexProcessor = ip;

        NSString *queueLabel = [@"com.simperium.processor." stringByAppendingString:self.name];
        processorQueue = dispatch_queue_create([queueLabel cStringUsingEncoding:NSUTF8StringEncoding], NULL);

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectDidChange:)
                                                     name:ProcessorDidChangeObjectNotification object:self];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectsAdded:)
                                                     name:ProcessorDidAddObjectsNotification object:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectKeysDeleted:)
                                                     name:ProcessorDidDeleteObjectKeysNotification object:self];        

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectsAcknowledged:)
                                                     name:ProcessorDidAcknowledgeObjectsNotification object:self];        

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectsWillChange:)
                                                     name:ProcessorWillChangeObjectsNotification object:self];        

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(acknowledgedObjectDeletion:)
                                                     name:ProcessorDidAcknowledgeDeleteNotification object:self];        

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLatestVersions)
                                                     name:ProcessorRequestsReindexing object:self];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ProcessorRequestsReindexing object:self];
}

- (id)objectForKey:(NSString *)simperiumKey {
    // Typically used on startup to get a dictionary from storage; Simperium doesn't keep it in memory though
    id<SPDiffable>diffable = [storage objectForKey:simperiumKey bucketName:self.name];
    return [diffable object];
}

- (id)objectAtIndex:(NSUInteger)index {
    id<SPDiffable>diffable = [storage objectAtIndex:index bucketName:self.name];
    return [diffable object];
}

- (void)requestVersions:(int)numVersions key:(NSString *)simperiumKey {
    id<SPDiffable>diffable = [storage objectForKey:simperiumKey bucketName:self.name];
    [network requestVersions:numVersions object:diffable];
}


- (NSArray *)allObjects {
    return [storage objectsForBucketName:self.name predicate:nil];
}

- (NSArray *)allObjectKeys {
    return [storage objectKeysForBucketName:self.name];
}

- (id)insertNewObject {
    id<SPDiffable>diffable = [storage insertNewObjectForBucketName:self.name simperiumKey:nil];
    diffable.bucket = self;
    return [diffable object];
}

- (id)insertNewObjectForKey:(NSString *)simperiumKey {
    id<SPDiffable>diffable = [storage insertNewObjectForBucketName:self.name simperiumKey:simperiumKey];
    diffable.bucket = self;
    return [diffable object];
}

- (void)insertObject:(id)object {
    //id<SPDiffable>diffable = [storage insertObject:object bucketName:self.name];
}

- (void)deleteAllObjects {
    [storage deleteAllObjectsForBucketName:self.name];
}

- (void)deleteObject:(id)object {
    [storage deleteObject:object];
}

- (void)updateDictionaryForKey:(NSString *)key {
//    id<SPDiffable>object = [storage objectForKey:key entityName:self.name];
//    if (!object) {
//        object = [storage insertNewObjectForEntityForName:self.name simperiumKey:key];
//    }
//    [object loadMemberData:data];
}

- (void)validateObjects {
    // Allow the storage to determine the most efficient way to validate everything
    [storage validateObjectsForBucketName: name];

    [storage save];
}

- (void)unloadAllObjects {
    [storage unloadAllObjects];
    [relationshipResolver reset:storage];
}

- (void)insertObject:(NSDictionary *)object atIndex:(NSUInteger)index {
    
}

- (NSArray *)objectsForKeys:(NSSet *)keys {
    return [storage objectsForKeys:keys bucketName:name];
}

- (NSArray *)objectsForPredicate:(NSPredicate *)predicate {
    return [storage objectsForBucketName:name predicate:predicate];
}


- (NSInteger)numObjects {
    return [storage numObjectsForBucketName:name predicate:nil];
}

- (NSInteger)numObjectsForPredicate:(NSPredicate *)predicate {
    return [storage numObjectsForBucketName:name predicate:predicate];
}

- (NSString *)lastChangeSignature {
    if (!lastChangeSignature) {
        // Load it
        NSString *sigKey = [NSString stringWithFormat:@"lastChangeSignature-%@", self.instanceLabel];
        NSString *signature = [[NSUserDefaults standardUserDefaults] objectForKey:sigKey];
        lastChangeSignature = [signature copy];
    }
	return lastChangeSignature;
}

- (void)setLastChangeSignature:(NSString *)signature {
	lastChangeSignature = [signature copy];
    
	// Persist it
	NSString *sigKey = [NSString stringWithFormat:@"lastChangeSignature-%@", self.instanceLabel];
	[[NSUserDefaults standardUserDefaults] setObject:lastChangeSignature forKey: sigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark Notifications

- (void)objectDidChange:(NSNotification *)notification {
    if ([delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:memberNames:)]) {
        // Only one object changed; get it
        NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
        NSString *key = [[set allObjects] objectAtIndex:0];
        NSArray *changedMembers = (NSArray *)[notification.userInfo objectForKey:@"changedMembers"];
        [delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeUpdate memberNames:changedMembers];
    }
}

- (void)objectsAdded:(NSNotification *)notification {
    // When objects are added, resolve any references to them that hadn't yet been fulfilled
    // Note: this notification isn't currently triggered from SPIndexProcessor when adding objects from the index. Instead,
    // references are resolved from within SPIndexProcessor itself
    NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
    [self resolvePendingRelationshipsToKeys:set];

    // Also notify the delegate since the referenced objects are now accessible
    if ([delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:memberNames:)]) {
        for (NSString *key in set) {
            [delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeInsert memberNames:nil];
        }
    }
}

- (void)objectKeysDeleted:(NSNotification *)notification  {
    NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
    BOOL delegateRespondsToSelector = [delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:memberNames:)];

    for (NSString *key in set) {
        [storage stopManagingObjectWithKey:key];
        if (delegateRespondsToSelector)
            [delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeDelete memberNames:nil];
    }
}

- (void)objectsAcknowledged:(NSNotification *)notification  {
    if ([delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:memberNames:)]) {
        NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
        for (NSString *key in set) {
            [delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeAcknowledge memberNames:nil];
        }
    }
}

- (void)objectsWillChange:(NSNotification *)notification  {
    if ([delegate respondsToSelector:@selector(bucket:willChangeObjectsForKeys:)]) {
        NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
        [delegate bucket:self willChangeObjectsForKeys:set];
    }
}

- (void)acknowledgedObjectDeletion:(NSNotification *)notification {
    if ([delegate respondsToSelector:@selector(bucketDidAcknowledgeDelete:)]) {
        [delegate bucketDidAcknowledgeDelete:self];
    }    
}

- (void)requestLatestVersions {
    [network requestLatestVersionsForBucket:self];
}

- (SPSchema *)schema {
    return differ.schema;
}

- (void)setSchema:(SPSchema *)aSchema {
    differ.schema = aSchema;
}

- (void)resolvePendingRelationshipsToKeys:(NSSet *)keys {
    for (NSString *key in keys)
        [self.relationshipResolver resolvePendingRelationshipsToKey:key bucketName:self.name storage:self.storage];
}

- (void)forceSyncWithCompletion:(SPBucketForceSyncCompletion)completion {
	self.forceSyncCompletion = completion;
	[self.network forceSyncBucket:self];
}

- (void)bucketDidSync {
	if(self.changeProcessor.numChangesPending == 0 && self.forceSyncCompletion) {
		self.forceSyncCompletion();
		self.forceSyncCompletion = nil;
	}
}

@end
