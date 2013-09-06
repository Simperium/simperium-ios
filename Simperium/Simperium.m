//
//  Simperium.m
//
//  Created by Michael Johnston on 11-02-11.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "Simperium.h"
#import "SPUser.h"
#import "SPSchema.h"
#import "SPManagedObject.h"
#import "SPBinaryManager.h"
#import "SPJSONStorage.h"
#import "SPStorageObserver.h"
#import "SPMember.h"
#import "SPMemberBinary.h"
#import "SPDiffer.h"
#import "SPGhost.h"
#import "SPEnvironment.h"
#import "SPHttpInterface.h"
#import "SPWebSocketInterface.h"
#import "ASIHTTPRequest.h"
#import "JSONKit.h"
#import "NSString+Simperium.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"
#import "SPCoreDataStorage.h"
#import "SPAuthenticator.h"
#import "SPBucket.h"
#import "SPRelationshipResolver.h"
#import "SPReachability.h"

#if TARGET_OS_IPHONE
#import "SPAuthenticationViewController.h"
#else
#import "SPAuthenticationWindowController.h"
#endif


@interface Simperium() <SPStorageObserver>

@property (nonatomic, strong) SPCoreDataStorage *coreDataStorage;
@property (nonatomic, strong) SPJSONStorage *JSONStorage;
@property (nonatomic, strong) NSMutableDictionary *buckets;
@property (nonatomic, strong) id<SPNetworkInterface> network;
@property (nonatomic, strong) SPRelationshipResolver *relationshipResolver;
@property (nonatomic) BOOL skipContextProcessing;
@property (nonatomic) BOOL networkManagersStarted;
@property (nonatomic) BOOL dynamicSchemaEnabled;
@property (nonatomic, strong) SPReachability *reachability;


#if TARGET_OS_IPHONE
@property (nonatomic, strong) SPAuthenticationViewController *authenticationViewController;
#else
@property (nonatomic, strong) SPAuthenticationWindowController *authenticationWindowController;
#endif

-(BOOL)save;
@end


@implementation Simperium

#pragma mark - Properties
@synthesize user;
@synthesize label;
@synthesize JSONStorage;
@synthesize coreDataStorage;
@synthesize skipContextProcessing;
@synthesize networkManagersStarted;
@synthesize dynamicSchemaEnabled;
@synthesize verboseLoggingEnabled = _verboseLoggingEnabled;
@synthesize networkEnabled = _networkEnabled;
@synthesize authenticationEnabled = _authenticationEnabled;
@synthesize useWebSockets = _useWebSockets;
@synthesize authenticator;
@synthesize network;
@synthesize relationshipResolver;
@synthesize binaryManager;
@synthesize buckets;
@synthesize appID;
@synthesize APIKey;
@synthesize appURL;
@synthesize delegate;
@synthesize bucketOverrides;
@synthesize authenticationOptional;
@synthesize rootURL = _rootURL;
@synthesize reachability;

#if TARGET_OS_IPHONE
@synthesize rootViewController;
@synthesize authenticationViewController;
@synthesize authenticationViewControllerClass;
#else
@synthesize window;
@synthesize authenticationWindowController;
@synthesize authenticationWindowControllerClass;
#endif


#ifdef DEBUG
static int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static int ddLogLevel = LOG_LEVEL_INFO;
#endif

+ (int)ddLogLevel {
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    ddLogLevel = logLevel;
}

#pragma mark - Constructors
-(id)init
{
	if ((self = [super init])) {
        
        // Handle multiple Simperium instances by ensuring logging only gets started once
        static BOOL loggingStarted;
        if (!loggingStarted) {
            [DDLog addLogger:[DDASLLogger sharedInstance]];
            [DDLog addLogger:[DDTTYLogger sharedInstance]];
            loggingStarted = YES;
        }
        
        self.label = @"";
        _networkEnabled = YES;
        _authenticationEnabled = YES;
        _useWebSockets = NO;
        dynamicSchemaEnabled = YES;
		[ASIHTTPRequest setShouldUpdateNetworkActivityIndicator:NO];
        self.buckets = [NSMutableDictionary dictionary];
        
        SPAuthenticator *auth = [[SPAuthenticator alloc] initWithDelegate:self simperium:self];
        self.authenticator = auth;
        
        SPRelationshipResolver *resolver = [[SPRelationshipResolver alloc] init];
        self.relationshipResolver = resolver;

#if TARGET_OS_IPHONE
        authenticationViewControllerClass = [SPAuthenticationViewController class];
#else
        authenticationWindowControllerClass = [SPAuthenticationWindowController class];
#endif
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authenticationDidFail)
                                                     name:SPAuthenticationDidFail object:nil];
    }

	return self;
}

#if TARGET_OS_IPHONE
-(id)initWithRootViewController:(UIViewController *)controller
{
    if ((self = [self init])) {
        rootViewController = controller;
    }
    
    return self;
}
#else
-(id)initWithWindow:(NSWindow *)aWindow
{
    if ((self = [self init])) {
        window = aWindow;
        
        // Hide window by default - authenticating will make it visible
        [window orderOut:nil];
    }
    
    return self;
}
#endif

-(void)dealloc
{
    [self stopNetworking];
    self.rootURL = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)setClientID:(NSString *)cid {
    clientID = [cid copy];
}

-(NSString *)clientID {
    if (!clientID || clientID.length == 0) {
        NSString *agentPrefix;
#if TARGET_OS_IPHONE
        agentPrefix = @"ios";
#else
        agentPrefix = @"osx";
#endif
        // Unique client ID per session is sufficient
        NSString *uuid = [NSString sp_makeUUID];
        clientID = [[NSString stringWithFormat:@"%@-%@", agentPrefix, uuid] copy];
    }
    return clientID;
}


-(void)setLabel:(NSString *)aLabel {
    label = [aLabel copy];
    
    // Set the clientID as well, otherwise certain change operations won't work (since they'll appear to come from
    // the same Simperium instance)
    clientID = [label copy];
}

-(NSString *)label {
    return label;
}

-(void)configureBinaryManager:(SPBinaryManager *)manager {    
    // Binary members need to know about the manager (ugly but avoids singleton/global)
    for (SPBucket *bucket in [buckets allValues]) {
        for (SPMemberBinary *binaryMember in bucket.differ.schema.binaryMembers) {
            binaryMember.binaryManager = manager;
        }
    }
}

-(NSString *)addBinary:(NSData *)binaryData toObject:(SPManagedObject *)object bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName {
    return [binaryManager addBinary:binaryData toObject:object bucketName:bucketName attributeName:attributeName];
}

-(void)addBinaryWithFilename:(NSString *)filename toObject:(SPManagedObject *)object bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName {
    // Make sure the object has a simperiumKey (it might not if it was just created)
    if (!object.simperiumKey)
        object.simperiumKey = [NSString sp_makeUUID];
    return [binaryManager addBinaryWithFilename:filename toObject:object bucketName:bucketName attributeName:attributeName];
}

-(NSData *)dataForFilename:(NSString *)filename {
    return [binaryManager dataForFilename:filename];
}

-(SPBucket *)bucketForName:(NSString *)name { 
    SPBucket *bucket = [buckets objectForKey:name];
    if (!bucket) {
        // First check for an override
        for (NSString *testName in [bucketOverrides allKeys]) {
            NSString *testOverride = [bucketOverrides objectForKey:testName];
            if ([testOverride isEqualToString:name])
                return [buckets objectForKey:testName];
        }
        
        // Lazily start buckets
        if (dynamicSchemaEnabled) {
            // Create and start a network manager for it
            SPSchema *schema = [[SPSchema alloc] initWithBucketName:name data:nil];
            schema.dynamic = YES;
            SPHttpInterface *netManager = [[SPHttpInterface alloc] initWithSimperium:self appURL:self.appURL clientID:self.clientID];
            
            // New buckets use JSONStorage by default (you can't manually create a Core Data bucket)
            bucket = [[SPBucket alloc] initWithSchema:schema storage:self.JSONStorage networkInterface:network
                                 relationshipResolver:self.relationshipResolver label:self.label];
            [netManager setBucket:bucket overrides:self.bucketOverrides];
            [buckets setObject:bucket forKey:name];
            [netManager start:bucket name:bucket.name];
            

        } else
            return nil;
    }
    
    return bucket;
}

-(void)shareObject:(SPManagedObject *)object withEmail:(NSString *)email
{
    SPBucket *bucket = [buckets objectForKey:object.bucket.name];
    [bucket.network shareObject: object withEmail:email];
}

-(void)setVerboseLoggingEnabled:(BOOL)on {
    _verboseLoggingEnabled = on;
    for (Class cls in [DDLog registeredClasses]) {
        [DDLog setLogLevel:on ? LOG_LEVEL_VERBOSE : LOG_LEVEL_INFO forClass:cls];
    }
}

-(void)startNetworkManagers
{    
    if (!self.networkEnabled || networkManagersStarted)
        return;
    
    DDLogInfo(@"Simperium starting network managers...");
    // Finally, start the network managers to start syncing data
    for (SPBucket *bucket in [buckets allValues]) {
        // TODO: move nameOverride into the buckets themselves
        NSString *nameOverride = [bucketOverrides objectForKey:bucket.name];
        [bucket.network start:bucket name:nameOverride && nameOverride.length > 0 ? nameOverride : bucket.name];
	}
    networkManagersStarted = YES;
}

-(void)stopNetworkManagers
{
    if (!networkManagersStarted)
        return;
    
    for (SPBucket *bucket in [buckets allValues]) {
        [bucket.network stop:bucket];
    }
    networkManagersStarted = NO;
}

-(void)startNetworking
{
    // Create a new one each time to make sure it fires (and causes networking to start)
    self.reachability = [SPReachability reachabilityWithHostName:@"api.simperium.com"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    [self.reachability startNotifier];
}

-(void)stopNetworking
{
    [self stopNetworkManagers];
}

-(void)handleNetworkChange:(NSNotification *)notification {
	
	if ([self.reachability currentReachabilityStatus] == NotReachable) {
        [self stopNetworkManagers];
    } else if(self.user.authenticated) {
        [self startNetworkManagers];
    }
}

-(void)setNetworkEnabled:(BOOL)enabled
{
    if (_networkEnabled == enabled)
        return;
    
    _networkEnabled = enabled;
    if (enabled) {
        [self authenticateIfNecessary];
    } else
        [self stopNetworking];
}

-(NSMutableDictionary *)loadBuckets:(NSArray *)schemas
{
    NSMutableDictionary *bucketList = [NSMutableDictionary dictionaryWithCapacity:[schemas count]];
    SPBucket *bucket;
    
    for (SPSchema *schema in schemas) {
//        Class entityClass = NSClassFromString(schema.bucketName);
//        NSAssert1(entityClass != nil, @"Simperium error: couldn't find a class mapping for: ", schema.bucketName);
        
        // If bucket overrides exist, but this entityClassName isn't included in them, then don't start a network
        // manager for that bucket. This provides simple bucket exclusion for unit tests.
        if (self.bucketOverrides != nil && [self.bucketOverrides objectForKey:schema.bucketName] == nil)
            continue;
        
        if (self.useWebSockets) {
            // For websockets, one network manager for all buckets
            if (!self.network) {
                SPWebSocketInterface *webSocketManager = [[SPWebSocketInterface alloc] initWithSimperium:self appURL:self.appURL clientID:self.clientID];
                self.network = webSocketManager;
            }
            bucket = [[SPBucket alloc] initWithSchema:schema storage:self.coreDataStorage networkInterface:self.network
                                 relationshipResolver:self.relationshipResolver label:self.label];
        } else {
            // For http, each bucket has its own network manager
            SPHttpInterface *netInterface = [[SPHttpInterface alloc] initWithSimperium:self appURL:self.appURL clientID:self.clientID];
            bucket = [[SPBucket alloc] initWithSchema:schema storage:self.coreDataStorage networkInterface:netInterface
                                 relationshipResolver:self.relationshipResolver label:self.label];
            [(SPHttpInterface *)netInterface setBucket:bucket overrides:self.bucketOverrides]; // tightly coupled for now; will fix in websockets netmanager
        }
        
        [bucketList setObject:bucket forKey:schema.bucketName];
    }
    
    if (self.useWebSockets) {
        [(SPWebSocketInterface *)self.network loadChannelsForBuckets:bucketList overrides:self.bucketOverrides];
    }
    
    return bucketList;
}

-(void)validateObjects {
    for (SPBucket *bucket in [self.buckets allValues]) {
        // Check all existing objects (e.g. in case there are existing ones that aren't in Simperium yet)
        [bucket validateObjects];
    }
    // No need to save, each bucket saves after validation
}

-(void)setAllBucketDelegates:(id)aDelegate {
    for (SPBucket *bucket in [buckets allValues]) {
        bucket.delegate = aDelegate;
    }
}

-(NSString *)rootURL {
    return _rootURL;
}

-(void)setRootURL:(NSString *)url {
    _rootURL = [url copy];
    
    appURL = [[_rootURL stringByAppendingFormat:@"%@/", appID] copy];
}

-(void)startWithAppID:(NSString *)identifier APIKey:(NSString *)key {
    DDLogInfo(@"Simperium starting... %@", label);
	
	// Enforce required parameters
	NSParameterAssert(identifier);
	NSParameterAssert(key);
	
	// Keep the keys!
    appID = [identifier copy];
    APIKey = [key copy];
    self.rootURL = SPBaseURL;
    
    // Setup JSON storage
    SPJSONStorage *storage = [[SPJSONStorage alloc] initWithDelegate:self];
    self.JSONStorage = storage;
    
    // Network managers (load but don't start yet)
    //[self loadNetworkManagers];
    
    // Check all existing objects (e.g. in case there are existing ones that aren't in Simperium yet)
    //    [objectManager validateObjects];
    
    if (self.authenticationEnabled) {
        [self authenticateIfNecessary];
    }
}

-(void)startWithAppID:(NSString *)identifier APIKey:(NSString *)key model:(NSManagedObjectModel *)model context:(NSManagedObjectContext *)context coordinator:(NSPersistentStoreCoordinator *)coordinator
{
	DDLogInfo(@"Simperium starting... %@", label);
	
	// Enforce required parameters
	NSParameterAssert(identifier);
	NSParameterAssert(key);
	NSParameterAssert(model);
	NSParameterAssert(context);
	NSParameterAssert(coordinator);
	
	NSAssert((context.concurrencyType == NSMainQueueConcurrencyType), NSLocalizedString(@"Error: you must initialize your context with 'NSMainQueueConcurrencyType' concurrency type.", nil));
	NSAssert((context.persistentStoreCoordinator == nil), NSLocalizedString(@"Error: NSManagedObjectContext's persistentStoreCoordinator must be nil. Simperium will handle CoreData connections for you.", nil));
	
	// Keep the keys!
    appID = [identifier copy];
    APIKey = [key copy];
    self.rootURL = SPBaseURL;
    
    // Setup Core Data storage
    SPCoreDataStorage *storage = [[SPCoreDataStorage alloc] initWithModel:model mainContext:context coordinator:coordinator];
    self.coreDataStorage = storage;
    self.coreDataStorage.delegate = self;
    
    // Get the schema from Core Data    
    NSArray *schemas = [self.coreDataStorage exportSchemas];
    
    // Load but don't start yet
    self.buckets = [self loadBuckets:schemas];
    
    // Each NSManagedObject stores a reference to the bucket in which it's stored
    [self.coreDataStorage setBucketList: self.buckets];
    
    // Load metadata for pending references among objects
    [self.relationshipResolver loadPendingRelationships:self.coreDataStorage];
    
    if (self.binaryManager) {
        [self configureBinaryManager:self.binaryManager];
	}
    
    // With everything configured, all objects can now be validated. This will pick up any objects that aren't yet
    // known to Simperium (for the case where you're adding Simperium to an existing app).
    [self validateObjects];
                            
    if (self.authenticationEnabled) {
        [self authenticateIfNecessary];
    }    
}

#pragma mark SPStorageObserver

-(BOOL)objectsShouldSync {
    // TODO: rename or possibly (re)move this
    return !skipContextProcessing;
}

-(void)storage:(id<SPStorageProvider>)storage updatedObjects:(NSSet *)updatedObjects insertedObjects:(NSSet *)insertedObjects deletedObjects:(NSSet *)deletedObjects
{
    // This is automatically called by an SPStorage instance when data is locally changed and then saved

    // First deal with stashed objects (which are known to need a sync)
    NSMutableSet *unsavedObjects = [[storage stashedObjects] copy];

    // Unstash since they're about to be sent
    [storage unstashUnsavedObjects];
    
    for (id<SPDiffable>object in unsavedObjects) {
        if ([[object class] conformsToProtocol:@protocol(SPDiffable)])
            [object.bucket.network sendObjectChanges: object];
    }
    
    // Send changes for all unsaved, inserted and updated objects
    // The changes will automatically get batched and synced in the next tick
    
    for (id<SPDiffable>insertedObject in insertedObjects) {
        if ([[insertedObject class] conformsToProtocol:@protocol(SPDiffable)])
            [insertedObject.bucket.network sendObjectChanges: insertedObject];
    }
    
    for (id<SPDiffable>updatedObject in updatedObjects) {
        if ([[updatedObject class] conformsToProtocol:@protocol(SPDiffable)])
            [updatedObject.bucket.network sendObjectChanges: updatedObject];
    }
    
    // Send changes for all deleted objects
    for (id<SPDiffable>deletedObject in deletedObjects) {
        if ([[deletedObject class] conformsToProtocol:@protocol(SPDiffable)]) {
            [deletedObject.bucket.network sendObjectDeletion: deletedObject];
            [deletedObject.bucket.storage stopManagingObjectWithKey:deletedObject.simperiumKey];
        }
    }
}

#pragma mark Core Data

-(BOOL)save
{
    [self.JSONStorage save];
    [self.coreDataStorage save];
    return YES;
}

- (void)forceSyncWithTimeout:(NSTimeInterval)timeoutSeconds completion:(SimperiumForceSyncCompletion)completion
{
	dispatch_group_t group = dispatch_group_create();
	__block BOOL notified = NO;
	
	// Sync every bucket
	for(SPBucket* bucket in self.buckets.allValues) {
		dispatch_group_enter(group);
		[bucket forceSyncWithCompletion:^() {
			dispatch_group_leave(group);
		}];
	}

	// Wait until the workers are ready
	dispatch_group_notify(group, dispatch_get_main_queue(), ^ {
		if(!notified) {
			completion(YES);
			notified = YES;
		}
	});
	
	// Notify anyways after timeout
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeoutSeconds * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
		if(!notified) {
			completion(NO);
			notified = YES;
		}
    });
}

-(BOOL)saveWithoutSyncing {
    skipContextProcessing = YES;
    BOOL result = [self save];
    skipContextProcessing = NO;
    return result;
}

-(void)signOutAndRemoveLocalData:(BOOL)remove
{
    DDLogInfo(@"Simperium clearing local data...");
    
    // Reset Simperium
    [self stopNetworking];
    
    // Reset the network manager and processors; any enqueued tasks will get skipped
    for (SPBucket *bucket in [buckets allValues]) {
        [bucket unloadAllObjects];
        
        // This will block until everything is all clear
        [bucket.network resetBucketAndWait:bucket];
    }
    
    // Now delete all local content; no more changes will be coming in at this point
    if (remove) {
        skipContextProcessing = YES;
        for (SPBucket *bucket in [buckets allValues]) {
            [bucket deleteAllObjects];
        }
        skipContextProcessing = NO;
    }
    
    // Clear the token and user
    [authenticator reset];
    self.user = nil;

    // Don't start network managers again; expect app to handle that
}

-(NSManagedObjectContext *)managedObjectContext {
    return coreDataStorage.mainManagedObjectContext;
}

-(NSManagedObjectContext *)writerManagedObjectContext {
    return coreDataStorage.writerManagedObjectContext;
}

-(NSManagedObjectModel *)managedObjectModel {
    return coreDataStorage.managedObjectModel;
}

-(NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    return coreDataStorage.persistentStoreCoordinator;
}


-(void)authenticationDidSucceedForUsername:(NSString *)username token:(NSString *)token
{
    [binaryManager setupAuth:user];
    
    // It's now safe to start the network managers
    [self startNetworking];
        
    [self closeAuthViewControllerAnimated:YES];
}

-(void)authenticationDidCancel {
    [self stopNetworking];
    [self.authenticator reset];
    user.authToken = nil;
    [self closeAuthViewControllerAnimated:YES];
}

-(void)authenticationDidFail {
    [self stopNetworking];
    [self.authenticator reset];
    user.authToken = nil;
    
    if (self.authenticationEnabled)
        // Delay it a touch to avoid issues with storyboard-driven UIs
        [self performSelector:@selector(delayedOpenAuthViewController) withObject:nil afterDelay:0.1];
}

-(BOOL)authenticateIfNecessary
{
    if (!self.networkEnabled || !self.authenticationEnabled)
        return NO;
    
    [self stopNetworking];
    
    return [self.authenticator authenticateIfNecessary];    
}

-(void)delayedOpenAuthViewController {
    [self openAuthViewControllerAnimated:YES];
}

-(void)openAuthViewControllerAnimated:(BOOL)animated
{
#if TARGET_OS_IPHONE
    if (self.authenticationViewController && self.rootViewController.presentedViewController == self.authenticationViewController)
        return;
    
    SPAuthenticationViewController *loginController =  [[self.authenticationViewControllerClass alloc] init];
    self.authenticationViewController = loginController;
    self.authenticationViewController.authenticator = self.authenticator;
    
    if (!self.rootViewController) {
        UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        self.rootViewController = [window rootViewController];
        NSAssert(self.rootViewController, @"Simperium error: to use built-in authentication, you must configure a rootViewController when you initialize Simperium, or call setParentViewControllerForAuthentication:. This is how Simperium knows where to present a modal view. See enableManualAuthentication in the documentation if you want to use your own authentication interface.");
    }
    
    UIViewController *controller = self.authenticationViewController;
    UINavigationController *navController = nil;
    if (self.authenticationOptional) {
        navController = [[UINavigationController alloc] initWithRootViewController: self.authenticationViewController];
        controller = navController;
    }
    
	[self.rootViewController presentViewController:controller animated:animated completion:nil];
#else
    if (!authenticationWindowController) {
        authenticationWindowController = [[self.authenticationWindowControllerClass alloc] init];
        authenticationWindowController.authenticator = self.authenticator;
        authenticationWindowController.optional = authenticationOptional;
    }
    
    // Hide the main window and show the auth window instead
    [self.window setIsVisible:NO];    
    [[authenticationWindowController window] center];
    [[authenticationWindowController window] makeKeyAndOrderFront:self];
#endif
}

-(void)closeAuthViewControllerAnimated:(BOOL)animated
{   
#if TARGET_OS_IPHONE
    NSArray *childViewControllers = self.rootViewController.presentedViewController.childViewControllers;
    
    // Login can either be its own root, or the first child of a nav controller if auth is optional
    BOOL navLogin = [childViewControllers count] > 0 && [childViewControllers objectAtIndex:0] == self.authenticationViewController;
    if ((self.rootViewController.presentedViewController == self.authenticationViewController && self.authenticationViewController) || navLogin) {
        [self.rootViewController dismissViewControllerAnimated:animated completion:nil];
	}
    self.authenticationViewController = nil;
#else
    [self.window setIsVisible:YES];
    [[authenticationWindowController window] close];
    authenticationWindowController = nil;
#endif
}


-(void)shutdown
{
	
}


@end
