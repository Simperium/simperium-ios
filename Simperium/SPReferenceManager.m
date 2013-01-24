//
//  SPReferenceManager.m
//  Simperium
//
//  Created by Michael Johnston on 2012-08-22.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPReferenceManager.h"
#import "SPDiffable.h"
#import "SPStorage.h"
#import "JSONKit.h"
#import "SPGhost.h"
#import "DDLog.h"

#define PATH_KEY @"SPPathKey"
#define PATH_BUCKET @"SPPathBucket"
#define PATH_ATTRIBUTE @"SPPathAttribute"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface SPReferenceManager()
-(void)loadPendingReferences;
-(void)savePendingReferences;
@end


@implementation SPReferenceManager
@synthesize pendingReferences;

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

-(id)init
{
    if ((self = [super init])) {
        self.pendingReferences = [NSMutableDictionary dictionaryWithCapacity:10];
        [self loadPendingReferences];
    }
    
    return self;
}

-(void)dealloc {
    self.pendingReferences = nil;
    [super dealloc];
}

-(void)savePendingReferences
{
    if ([pendingReferences count] == 0) {
        // If there's already nothing there, save some CPU by not writing anything
        NSString *pendingKey = [NSString stringWithFormat:@"SPPendingReferences"];
        NSString *pendingJSON = [[NSUserDefaults standardUserDefaults] objectForKey:pendingKey];
        if (!pendingJSON)
            return;
    }
    
    NSString *json = [pendingReferences JSONString];
    NSString *key = [NSString stringWithFormat:@"SPPendingReferences"];
	[[NSUserDefaults standardUserDefaults] setObject:json forKey: key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)loadPendingReferences
{
    // Load changes that didn't get a chance to send
    NSString *pendingKey = [NSString stringWithFormat:@"SPPendingReferences"];
	NSString *pendingJSON = [[NSUserDefaults standardUserDefaults] objectForKey:pendingKey];
    NSDictionary *pendingDict = [pendingJSON objectFromJSONString];
    for (NSString *key in [pendingDict allKeys]) {
        // Manually create mutable children
        NSArray *loadPaths = [pendingDict objectForKey:key];
        NSMutableArray *paths = [NSMutableArray arrayWithArray:loadPaths];
        [pendingReferences setValue:paths forKey:key];
    }
}


-(BOOL)hasPendingReferenceToKey:(NSString *)key {
    return [pendingReferences objectForKey:key] != nil;
}

-(void)addPendingReferenceToKey:(NSString *)key fromKey:(NSString *)fromKey bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName
{
    if (key.length == 0) {
        DDLogWarn(@"Simperium warning: received empty pending reference to attribute %@", attributeName);
        return;
    }
    
    NSMutableDictionary *path = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 fromKey, PATH_KEY,
                                 bucketName, PATH_BUCKET,
                                 attributeName, PATH_ATTRIBUTE, nil];
    DDLogVerbose(@"Simperium adding pending reference from %@ (%@) to %@ (%@)", fromKey, attributeName, key, bucketName);
    
    // Check to see if any references are already being tracked for this entity
    NSMutableArray *paths = [pendingReferences objectForKey: key];
    if (paths == nil) {
        paths = [NSMutableArray arrayWithCapacity:3];
        [pendingReferences setObject: paths forKey: key];
    }
    [paths addObject:path];
    [self savePendingReferences];
}

-(void)resolvePendingReferencesToKey:(NSString *)toKey bucketName:(NSString *)bucketName storage:(id<SPStorageProvider>)storage;
{
    // The passed entity is now synced, so check for any pending references to it that can now be resolved
    NSMutableArray *paths = [pendingReferences objectForKey: toKey];
    if (paths != nil) {
        id<SPDiffable>toObject = [storage objectForKey:toKey bucketName:bucketName];
        
        if (!toObject) {
            DDLogError(@"Simperium error, tried to resolve reference to an object that doesn't exist yet (%@): %@", bucketName, toKey);
            return;
        }
        
        for (NSDictionary *path in paths) {
            // There'd be no way to get the entityName here since there's no way to look at an instance's members
            // Get it from the "path" instead
            NSString *fromKey = [path objectForKey:PATH_KEY];
            NSString *fromBucketName = [path objectForKey:PATH_BUCKET];
            NSString *attributeName = [path objectForKey:PATH_ATTRIBUTE];
            id<SPDiffable> fromObject = [storage objectForKey:fromKey bucketName:fromBucketName];
            DDLogVerbose(@"Simperium resolving pending reference for %@.%@=%@", fromKey, attributeName, toKey);
            [fromObject simperiumSetValue:toObject forKey: attributeName];
            
            // Get the key reference into the ghost as well
            [fromObject.ghost.memberData setObject:toKey forKey: attributeName];
            fromObject.ghost.needsSave = YES;
        }
        
        // All references to entity were resolved above, so remove it from the pending array
        [pendingReferences removeObjectForKey:toKey];
    }
    [storage save];
    [self savePendingReferences];
}

-(void)reset {
    [self.pendingReferences removeAllObjects];
    [self savePendingReferences];
}

@end
