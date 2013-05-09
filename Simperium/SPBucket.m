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
#import "SPNetworkProvider.h"
#import "SPChangeProcessor.h"
#import "SPIndexProcessor.h"
#import "DDLog.h"
#import "SPGhost.h"
#import "JSONKit.h"
#import "SPReferenceManager.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface SPBucket()
@end

@implementation SPBucket
@synthesize delegate;
@synthesize name;
@synthesize instanceLabel;
@synthesize storage;
@synthesize differ;
@synthesize network;
@synthesize referenceManager;
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

-(id)initWithSchema:(SPSchema *)aSchema storage:(id<SPStorageProvider>)aStorage networkProvider:(id<SPNetworkProvider>)netProvider referenceManager:(SPReferenceManager *)refManager label:(NSString *)label
{
    if ((self = [super init])) {
        name = [aSchema.bucketName copy];
        self.storage = aStorage;
        self.network = netProvider;
        self.referenceManager = refManager;

        SPDiffer *aDiffer = [[SPDiffer alloc] initWithSchema:aSchema];
        self.differ = aDiffer;
        [aDiffer release];

        // Label is used to support multiple simperium instances (e.g. unit testing)
        self.instanceLabel = [NSString stringWithFormat:@"%@%@", self.name, label];

        SPChangeProcessor *cp = [[SPChangeProcessor alloc] initWithLabel:self.instanceLabel];
        self.changeProcessor = cp;
        [cp release];

        SPIndexProcessor *ip = [[SPIndexProcessor alloc] init];
        self.indexProcessor = ip;
        [ip release];

        NSString *queueLabel = [@"com.simperium.processor." stringByAppendingString:self.name];
        processorQueue = dispatch_queue_create([queueLabel cStringUsingEncoding:NSUTF8StringEncoding], NULL);

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectsDidChange:)
                                                     name:ProcessorDidChangeObjectsNotification object:self];

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

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ProcessorRequestsReindexing object:self];
    [name release];
    name = nil;
    self.storage = nil;
    self.differ = nil;
    self.network = nil;
    self.changeProcessor = nil;
    self.indexProcessor = nil;
    [lastChangeSignature release];
    [super dealloc];
}

-(id)objectForKey:(NSString *)simperiumKey
{
    // Typically used on startup to get a dictionary from storage; Simperium doesn't keep it in memory though
    id<SPDiffable>diffable = [storage objectForKey:simperiumKey bucketName:self.name];
    return [diffable object];
}

-(id)objectAtIndex:(NSUInteger)index {
    id<SPDiffable>diffable = [storage objectAtIndex:index bucketName:self.name];
    return [diffable object];
}

-(void)requestVersions:(int)numVersions key:(NSString *)simperiumKey {
    id<SPDiffable>diffable = [storage objectForKey:simperiumKey bucketName:self.name];
    [network requestVersions:numVersions object:diffable];
}


-(NSArray *)allObjects {
    return [storage objectsForBucketName:self.name];
}

-(id)insertNewObject {
    id<SPDiffable>diffable = [storage insertNewObjectForBucketName:self.name simperiumKey:nil];
    diffable.bucket = self;
    return [diffable object];
}

-(id)insertNewObjectForKey:(NSString *)simperiumKey {
    id<SPDiffable>diffable = [storage insertNewObjectForBucketName:self.name simperiumKey:simperiumKey];
    diffable.bucket = self;
    return [diffable object];
}

-(void)insertObject:(id)object {
    //id<SPDiffable>diffable = [storage insertObject:object bucketName:self.name];
}

-(void)deleteAllObjects {
    [storage deleteAllObjectsForBucketName:self.name];
}

-(void)deleteObject:(id)object {
    [storage deleteObject:object];
}

-(void)updateDictionaryForKey:(NSString *)key {
//    id<SPDiffable>object = [storage objectForKey:key entityName:self.name];
//    if (!object) {
//        object = [storage insertNewObjectForEntityForName:self.name simperiumKey:key];
//    }
//    [object loadMemberData:data];
}

-(void)validateObjects
{
    // Allow the storage to determine the most efficient way to validate everything
    [storage validateObjectsForBucketName: name];

    [storage save];
}

-(void)unloadAllObjects {
    [storage unloadAllObjects];
    [referenceManager reset];
}

-(void)insertObject:(NSDictionary *)object atIndex:(NSUInteger)index {
    
}

-(NSArray *)objectsForKeys:(NSSet *)keys {
    return [storage objectsForKeys:keys bucketName:name];
}

-(NSInteger)numObjects {
    return [storage numObjectsForBucketName:name predicate:nil];
}

-(NSInteger)numObjectsForPredicate:(NSPredicate *)predicate {
    return [storage numObjectsForBucketName:name predicate:predicate];
}

-(NSString *)lastChangeSignature {
    if (!lastChangeSignature) {
        // Load it
        NSString *sigKey = [NSString stringWithFormat:@"lastChangeSignature-%@", self.instanceLabel];
        NSString *signature = [[NSUserDefaults standardUserDefaults] objectForKey:sigKey];
        lastChangeSignature = [signature copy];
    }
	return lastChangeSignature;
}

-(void)setLastChangeSignature:(NSString *)signature {
	[lastChangeSignature release];
	lastChangeSignature = [signature copy];
    
	// Persist it
	NSString *sigKey = [NSString stringWithFormat:@"lastChangeSignature-%@", self.instanceLabel];
	[[NSUserDefaults standardUserDefaults] setObject:lastChangeSignature forKey: sigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark Notifications

-(void)objectsDidChange:(NSNotification *)notification {
    if ([delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:)]) {
        NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
        for (NSString *key in set) {
            [delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeUpdate];
        }
    }
}

-(void)objectsAdded:(NSNotification *)notification {
    NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
    for (NSString *key in set) {
        [self.referenceManager resolvePendingReferencesToKey:key bucketName:self.name storage:storage]; // references must be intra-storage only
        [delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeInsert];
    }
}

-(void)objectKeysDeleted:(NSNotification *)notification  {
    NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
    BOOL delegateRespondsToSelector = [delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:)];

    for (NSString *key in set) {
        [storage stopManagingObjectWithKey:key];
        if (delegateRespondsToSelector)
            [delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeDelete];
    }
}

-(void)objectsAcknowledged:(NSNotification *)notification  {
    if ([delegate respondsToSelector:@selector(bucket:didChangeObjectForKey:forChangeType:)]) {
        NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
        for (NSString *key in set) {
            [delegate bucket:self didChangeObjectForKey:key forChangeType:SPBucketChangeAcknowledge];
        }
    }
}

-(void)objectsWillChange:(NSNotification *)notification  {
    if ([delegate respondsToSelector:@selector(bucket:willChangeObjectsForKeys:)]) {
        NSSet *set = (NSSet *)[notification.userInfo objectForKey:@"keys"];
        [delegate bucket:self willChangeObjectsForKeys:set];
    }
}

-(void)acknowledgedObjectDeletion:(NSNotification *)notification {
    if ([delegate respondsToSelector:@selector(bucketDidAcknowledgeDelete:)]) {
        [delegate bucketDidAcknowledgeDelete:self];
    }    
}

-(void)requestLatestVersions {
    [network requestLatestVersionsForBucket:self];
}

-(SPSchema *)schema {
    return differ.schema;
}

-(void)setSchema:(SPSchema *)aSchema {
    differ.schema = aSchema;
}

-(void)resolvePendingReferencesToKeys:(NSSet *)keys
{
    for (NSString *key in keys)
        [self.referenceManager resolvePendingReferencesToKey:key bucketName:self.name storage:self.storage];
}


// Potential future support for multiple delegates
//-(void)addDelegate:(id)delegate {
//    if (![delegates containsObject:delegate])
//        [delegates addObject: delegate];
//}
//
//-(void)removeDelegate:(id)delegate {
//    [delegates removeObject: delegate];
//}


@end
