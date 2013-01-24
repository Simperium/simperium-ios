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
#import "SPHttpManager.h"
#import "SPWebSocketManager.h"
#import "ASIHTTPRequest.h"
#import "JSONKit.h"
#import "NSString+Simperium.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"
#import "SPCoreDataStorage.h"
#import "SPAuthenticationManager.h"
#import "SPBucket.h"
#import "SPReferenceManager.h"
#import "Reachability.h"

#if TARGET_OS_IPHONE
#import "SPLoginViewController.h"
#else
#import "SPAuthWindowController.h"
#endif


@interface Simperium() <SPStorageObserver>

@property (nonatomic, retain) SPCoreDataStorage *coreDataStorage;
@property (nonatomic, retain) SPJSONStorage *JSONStorage;
@property (nonatomic, retain) NSMutableDictionary *buckets;
@property (nonatomic, retain) SPAuthenticationManager *authManager;
@property (nonatomic, retain) id<SPNetworkProvider> network;
@property (nonatomic, retain) SPReferenceManager *referenceManager;
@property (nonatomic, assign) BOOL skipContextProcessing;
@property (nonatomic, assign) BOOL networkManagersStarted;
@property (nonatomic, assign) BOOL dynamicSchemaEnabled;
@property (nonatomic, retain) SPReachability *reachability;


#if TARGET_OS_IPHONE
@property (nonatomic, retain) SPLoginViewController *loginViewController;
#else
@property (nonatomic, retain) SPAuthWindowController *authWindowController;
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
@synthesize authManager;
@synthesize network;
@synthesize referenceManager;
@synthesize binaryManager;
@synthesize loginViewControllerClass;
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
@synthesize loginViewController;
#else
@synthesize window;
@synthesize authWindowController;
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
        
        SPAuthenticationManager *manager = [[SPAuthenticationManager alloc] initWithDelegate:self simperium:self];
        self.authManager = manager;
        [manager release];
        
        SPReferenceManager *refManager = [[SPReferenceManager alloc] init];
        self.referenceManager = refManager;
        [refManager release];

#if TARGET_OS_IPHONE
        loginViewControllerClass = [SPLoginViewController class];
#endif        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authenticationDidFail)
                                                     name:@"AuthenticationDidFailNotification" object:nil];
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
    self.buckets = nil;
    self.binaryManager = nil;
    self.user = nil;
    self.authManager = nil;
    self.coreDataStorage = nil;
    self.JSONStorage = nil;
    self.bucketOverrides = nil;
    self.referenceManager = nil;
    self.rootURL = nil;
    self.reachability = nil;
    [appID release];
    [APIKey release];
	[appURL release];
    [label release];
    
#if TARGET_OS_IPHONE
    self.loginViewController = nil;
#else
    self.authWindowController = nil;
#endif

	[super dealloc];
}

-(void)setClientID:(NSString *)cid {
    [clientID release];
    clientID = [cid copy];
}

-(NSString *)clientID {
    if (!clientID || clientID.length == 0) {
        // Hashed UDID
        // TODO: revisit due to iOS 5 deprecation
        NSString *agentPrefix;
#if TARGET_OS_IPHONE
        NSString *udid = [[UIDevice currentDevice] uniqueIdentifier];
        agentPrefix = @"ios";
#else
        // TODO: how should a Mac be identified?
        NSString *udid = [NSString sp_makeUUID];
        agentPrefix = @"osx";
#endif
        clientID = [NSString sp_md5StringFromData:[udid dataUsingEncoding:NSUTF8StringEncoding]];
        clientID = [[NSString stringWithFormat:@"%@-%@",agentPrefix, clientID] copy];
    }
    return clientID;
}


-(void)setLabel:(NSString *)aLabel {
    [label release];
    label = [aLabel copy];
    
    // Set the clientID as well, otherwise certain change operations won't work (since they'll appear to come from
    // the same Simperium instance)
    [clientID release];
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
            SPHttpManager *netManager = [[SPHttpManager alloc] initWithSimperium:self appURL:self.appURL clientID:self.clientID];
            
            // New buckets use JSONStorage by default (you can't manually create a Core Data bucket)
            bucket = [[SPBucket alloc] initWithSchema:schema storage:self.JSONStorage networkProvider:network referenceManager:self.referenceManager label:self.label];
            [netManager setBucket:bucket overrides:self.bucketOverrides];
            [buckets setObject:bucket forKey:name];
            [netManager start:bucket name:bucket.name];
            
            [bucket release];
            [netManager release];
            [schema release];

        } else
            return nil;
    }
    
    return bucket;
}

-(void)getVersions:(int)numVersions forObject:(id<SPDiffable>)object
{
    SPBucket *bucket = [object bucket];
    [bucket.network getVersions: numVersions forObject: object];
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
    //self.reachability = [SPReachability reachabilityForInternetConnection];
    self.reachability = [SPReachability reachabilityWithHostName:@"api.simperium.com"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    [self.reachability startNotifier]; 
}

-(void)stopNetworking
{
    [self.reachability stopNotifier];
    [self stopNetworkManagers];
}

-(void)handleNetworkChange:(NSNotification *)notification {
    if ([self.reachability currentReachabilityStatus] == NotReachable)
        [self stopNetworkManagers];
    else
        [self startNetworkManagers];
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
            if (!self.network)
                self.network = [[SPWebSocketManager alloc] initWithSimperium:self appURL:self.appURL clientID:self.clientID];
            bucket = [[SPBucket alloc] initWithSchema:schema storage:self.coreDataStorage networkProvider:self.network referenceManager:self.referenceManager label:self.label];
        } else {
            // For http, each bucket has its own network manager
            SPHttpManager *netProvider = [[SPHttpManager alloc] initWithSimperium:self appURL:self.appURL clientID:self.clientID];
            bucket = [[SPBucket alloc] initWithSchema:schema storage:self.coreDataStorage networkProvider:netProvider referenceManager:self.referenceManager label:self.label];
            [(SPHttpManager *)netProvider setBucket:bucket overrides:self.bucketOverrides]; // tightly coupled for now; will fix in websockets netmanager
            [netProvider release];
        }
                
        [bucketList setObject:bucket forKey:schema.bucketName];
        [bucket release];
    }
    
    if (self.useWebSockets) {
        [(SPWebSocketManager *)self.network loadChannelsForBuckets:bucketList overrides:self.bucketOverrides];
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
    [_rootURL release];
    _rootURL = [url copy];
    
    appURL = [[_rootURL stringByAppendingFormat:@"%@/", appID] copy];
}

-(void)startWithAppID:(NSString *)identifier APIKey:(NSString *)key {
    DDLogInfo(@"Simperium starting... %@", label);
    appID = [identifier copy];
    APIKey = [key copy];
    self.rootURL = SPBaseURL;
    
    // Setup JSON storage
    SPJSONStorage *storage = [[SPJSONStorage alloc] initWithDelegate:self];
    self.JSONStorage = storage;
    [storage release];
    
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
    appID = [identifier copy];
    APIKey = [key copy];
    self.rootURL = SPBaseURL;
    
    // Setup Core Data storage
    SPCoreDataStorage *storage = [[SPCoreDataStorage alloc] initWithModel:model context:context coordinator:coordinator];
    self.coreDataStorage = storage;
    self.coreDataStorage.delegate = self;
    [storage release];
    
    // Get the schema from Core Data    
    NSArray *schemas = [self.coreDataStorage exportSchemas];
    
    // Load but don't start yet
    self.buckets = [self loadBuckets:schemas];
    
    // Each NSManagedObject stores a reference to the bucket in which it's stored
    [self.coreDataStorage setBucketList: self.buckets];
    
    if (self.binaryManager)
        [self configureBinaryManager:self.binaryManager];
    
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
        [object.bucket.network sendObjectChanges: object];
    }
    [unsavedObjects release];
    
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
    [authManager reset];
    [user release];
    user = nil;
    
    // Don't start network managers again; expect app to handle that
}

-(NSManagedObjectContext *)managedObjectContext {
    return coreDataStorage.managedObjectContext;
}

-(NSManagedObjectModel *)managedObjectModel {
    return coreDataStorage.managedObjectModel;
}

-(NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    return coreDataStorage.persistentStoreCoordinator;
}


-(void)authenticationDidSucceedForUsername:(NSString *)username token:(NSString *)token
{
#if TARGET_OS_IPHONE
#else
    [self.window makeKeyAndOrderFront:nil];
#endif

    [binaryManager setupAuth:user];
    
    // It's now safe to start the network managers
    [self startNetworking];
        
    [self closeAuthViewControllerAnimated:YES];
}

-(void)authenticationDidCancel {
    [self stopNetworking];
    [self.authManager reset];
    user.authToken = nil;
    [self closeAuthViewControllerAnimated:YES];
}

-(void)authenticationDidFail {
    [self stopNetworking];
    [self.authManager reset];
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
    
    return [self.authManager authenticateIfNecessary];    
}

-(void)delayedOpenAuthViewController {
    [self openAuthViewControllerAnimated:YES];
}

-(void)openAuthViewControllerAnimated:(BOOL)animated
{
#if TARGET_OS_IPHONE
    if (self.loginViewController && self.rootViewController.presentedViewController == self.loginViewController)
        return;
    
    self.loginViewController = [[self.loginViewControllerClass alloc] initWithNibName:@"LoginView" bundle:nil];
    self.loginViewController.authManager = self.authManager;
    
    if (!self.rootViewController) {
        UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        self.rootViewController = [window rootViewController];
        NSAssert(self.rootViewController, @"Simperium error: to use built-in authentication, you must configure a rootViewController when you initialize Simperium, or call setParentViewControllerForAuthentication:. This is how Simperium knows where to present a modal view. See enableManualAuthentication in the documentation if you want to use your own authentication interface.");
    }
    
    UIViewController *controller = self.loginViewController;
    if (self.authenticationOptional) {
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController: self.loginViewController];
        controller = navController;
    }
    
    [self.rootViewController presentModalViewController:controller animated:animated];
    [controller release];
#else
    if (!authWindowController) {
        SPAuthWindowController *anAuthWindowController = [[SPAuthWindowController alloc] initWithWindowNibName:@"AuthWindow"];
        anAuthWindowController.authManager = self.authManager;
        
        authWindowController = [anAuthWindowController retain];
        [anAuthWindowController release];
    }
    
    [[authWindowController window] center];
    [[authWindowController window] makeKeyAndOrderFront:self];
    
    
    //    [NSApp beginSheet:[authWindowController window]
    //       modalForWindow:window
    //        modalDelegate:self
    //       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
    //          contextInfo:nil];
    //    [NSApp runModalForWindow: [authWindowController window]];
    //    // Dialog is up here.
    //    [NSApp endSheet: [authWindowController window]];
    //    [[authWindowController window] orderOut: self];
#endif
}

-(void)closeAuthViewControllerAnimated:(BOOL)animated
{   
#if TARGET_OS_IPHONE
    NSArray *childViewControllers = self.rootViewController.presentedViewController.childViewControllers;
    
    // Login can either be its own root, or the first child of a nav controller if auth is optional
    BOOL navLogin = [childViewControllers count] > 0 && [childViewControllers objectAtIndex:0] == self.loginViewController;
    if ((self.rootViewController.presentedViewController == self.loginViewController && self.loginViewController) || navLogin)
        [self.rootViewController dismissModalViewControllerAnimated:animated];
    self.loginViewController = nil;
#else
    //[NSApp endSheet:[authWindowController window] returnCode:NSOKButton];
    [[authWindowController window] close];
#endif
}


-(void)shutdown
{
	
}


@end
