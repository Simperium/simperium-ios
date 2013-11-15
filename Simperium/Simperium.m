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
#import "SPBinaryManager+Internals.h"
#import "SPJSONStorage.h"
#import "SPStorageObserver.h"
#import "SPMember.h"
#import "SPMemberBinaryInfo.h"
#import "SPDiffer.h"
#import "SPGhost.h"
#import "SPEnvironment.h"
#import "SPWebSocketInterface.h"
#import "JSONKit+Simperium.h"
#import "NSString+Simperium.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"
#import "DDFileLogger+Simperium.h"
#import "SPSimperiumLogger.h"
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

NSString * const UUID_KEY = @"SPUUIDKey";



#pragma mark ====================================================================================
#pragma mark Simperium: Private Methods
#pragma mark ====================================================================================

@interface Simperium() <SPStorageObserver, SPAuthenticatorDelegate, SPSimperiumLoggerDelegate>

@property (nonatomic, strong) SPCoreDataStorage			*coreDataStorage;
@property (nonatomic, strong) SPJSONStorage				*JSONStorage;
@property (nonatomic, strong) NSMutableDictionary		*buckets;
@property (nonatomic, strong) id<SPNetworkInterface>	network;
@property (nonatomic, strong) SPRelationshipResolver	*relationshipResolver;
@property (nonatomic, strong) SPReachability			*reachability;
@property (nonatomic,	copy) NSString					*clientID;
@property (nonatomic,	copy) NSString					*appID;
@property (nonatomic,	copy) NSString					*APIKey;
@property (nonatomic,	copy) NSString					*appURL;
@property (nonatomic, assign) BOOL						skipContextProcessing;
@property (nonatomic, assign) BOOL						networkManagersStarted;
@property (nonatomic, assign) BOOL						dynamicSchemaEnabled;

#if TARGET_OS_IPHONE
@property (nonatomic, strong) SPAuthenticationViewController *authenticationViewController;
#else
@property (nonatomic, strong) SPAuthenticationWindowController *authenticationWindowController;
#endif

- (BOOL)save;
@end


#pragma mark ====================================================================================
#pragma mark Simperium
#pragma mark ====================================================================================

@implementation Simperium

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

+ (void)setupLogging {
	// Handle multiple Simperium instances by ensuring logging only gets started once
    static dispatch_once_t _once;
    dispatch_once(&_once, ^{
		[DDLog addLogger:[DDASLLogger sharedInstance]];
		[DDLog addLogger:[DDTTYLogger sharedInstance]];
		[DDLog addLogger:[DDFileLogger sharedInstance]];
		[DDLog addLogger:[SPSimperiumLogger sharedInstance]];
	});
}


#pragma mark - Constructors
- (id)init {
	if ((self = [super init])) {

        [[self class] setupLogging];
        
        self.label = @"";
        self.networkEnabled = YES;
        self.authenticationEnabled = YES;
        self.dynamicSchemaEnabled = YES;
        self.buckets = [NSMutableDictionary dictionary];
        
        SPAuthenticator *auth = [[SPAuthenticator alloc] initWithDelegate:self simperium:self];
        self.authenticator = auth;
        
        SPRelationshipResolver *resolver = [[SPRelationshipResolver alloc] init];
        self.relationshipResolver = resolver;

		SPSimperiumLogger *logger = [SPSimperiumLogger sharedInstance];
		logger.delegate = self;
		
#if TARGET_OS_IPHONE
        self.authenticationViewControllerClass = [SPAuthenticationViewController class];
#else
        self.authenticationWindowControllerClass = [SPAuthenticationWindowController class];
#endif
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authenticationDidFail)
                                                     name:SPAuthenticationDidFail object:nil];
    }

	return self;
}

#if TARGET_OS_IPHONE
- (id)initWithRootViewController:(UIViewController *)controller {
    if ((self = [self init])) {
        self.rootViewController = controller;
    }
    
    return self;
}
#else
- (id)initWithWindow:(NSWindow *)aWindow {
    if ((self = [self init])) {
        self.window = aWindow;
        
        // Hide window by default - authenticating will make it visible
        [self.window orderOut:nil];
    }
    
    return self;
}
#endif

- (void)dealloc {
    [self stopNetworking];
    self.rootURL = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)clientID {
    if (!_clientID || _clientID.length == 0) {
        // Unique client ID; persist it so changes sent between sessions come from the same client ID
        NSString *uuid = [[NSUserDefaults standardUserDefaults] objectForKey:UUID_KEY];
        if (!uuid) {
            uuid = [NSString sp_makeUUID];
            [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:UUID_KEY];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        _clientID = [[NSString stringWithFormat:@"%@-%@", SPLibraryID, uuid] copy];
    }
    return _clientID;
}

- (void)setLabel:(NSString *)aLabel {
    _label = [aLabel copy];
    
    // Set the clientID as well, otherwise certain change operations won't work (since they'll appear to come from
    // the same Simperium instance)
    self.clientID = _label;
}

- (SPBucket *)bucketForName:(NSString *)name {
    SPBucket *bucket = [self.buckets objectForKey:name];

    if (!bucket) {
        // First check for an override
        for (NSString *testName in [self.bucketOverrides allKeys]) {
            NSString *testOverride = [self.bucketOverrides objectForKey:testName];
            if ([testOverride isEqualToString:name]) {
                return [self.buckets objectForKey:testName];
			}
        }
        
        // Lazily start buckets
        if (self.dynamicSchemaEnabled) {
            // Create and start a network manager for it
            SPSchema *schema = [[SPSchema alloc] initWithBucketName:name data:nil];
            schema.dynamic = YES;
			
			// For websockets, one network manager for all buckets
			if (!self.network) {
				self.network = [SPWebSocketInterface interfaceWithSimperium:self appURL:self.appURL clientID:self.clientID];
			}
						
			// New buckets use JSONStorage by default (you can't manually create a Core Data bucket)
			bucket = [[SPBucket alloc] initWithSchema:schema storage:self.JSONStorage networkInterface:self.network binaryManager:self.binaryManager
								 relationshipResolver:self.relationshipResolver label:self.label];

			[self.buckets setObject:bucket forKey:name];
            [self.network start:bucket name:bucket.name];
        }
    }
    
    return bucket;
}

- (void)shareObject:(SPManagedObject *)object withEmail:(NSString *)email {
    SPBucket *bucket = [self.buckets objectForKey:object.bucket.name];
    [bucket.network shareObject: object withEmail:email];
}

- (void)setVerboseLoggingEnabled:(BOOL)on {
    _verboseLoggingEnabled = on;
    for (Class cls in [DDLog registeredClasses]) {
        [DDLog setLogLevel:on ? LOG_LEVEL_VERBOSE : LOG_LEVEL_INFO forClass:cls];
    }
}

- (NSData*)exportLogfiles {
	return [[DDFileLogger sharedInstance] exportLogfiles];
}

- (void)startNetworkManagers {
    if (!self.networkEnabled || self.networkManagersStarted) {
        return;
	}
    
    DDLogInfo(@"Simperium starting network managers...");
    // Finally, start the network managers to start syncing data
    for (SPBucket *bucket in [self.buckets allValues]) {
        // TODO: move nameOverride into the buckets themselves
        NSString *nameOverride = [self.bucketOverrides objectForKey:bucket.name];
        [bucket.network start:bucket name:nameOverride && nameOverride.length > 0 ? nameOverride : bucket.name];
	}
	
	[self.binaryManager start];
	
    self.networkManagersStarted = YES;
}

- (void)stopNetworkManagers {
    if (!self.networkManagersStarted) {
        return;
    }
	
    for (SPBucket *bucket in [self.buckets allValues]) {
        [bucket.network stop:bucket];
    }
	
	[self.binaryManager stop];
    self.networkManagersStarted = NO;
}

- (void)startNetworking {
    // Create a new one each time to make sure it fires (and causes networking to start)
    self.reachability = [SPReachability reachabilityWithHostName:@"api.simperium.com"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    [self.reachability startNotifier];
}

- (void)stopNetworking {
    [self stopNetworkManagers];
}

- (void)handleNetworkChange:(NSNotification *)notification {
	if ([self.reachability currentReachabilityStatus] == NotReachable) {
        [self stopNetworkManagers];
    } else if (self.user.authenticated) {
        [self startNetworkManagers];
    }
}

- (void)setNetworkEnabled:(BOOL)enabled {
    if (self.networkEnabled == enabled) {
        return;
    }
	
    _networkEnabled = enabled;
    if (enabled) {
        [self authenticateIfNecessary];
    } else {
        [self stopNetworking];
	}
}

- (NSMutableDictionary *)loadBuckets:(NSArray *)schemas {
    NSMutableDictionary *bucketList = [NSMutableDictionary dictionaryWithCapacity:[schemas count]];
    SPBucket *bucket;
    
    for (SPSchema *schema in schemas) {
//        Class entityClass = NSClassFromString(schema.bucketName);
//        NSAssert1(entityClass != nil, @"Simperium error: couldn't find a class mapping for: ", schema.bucketName);
        
        // If bucket overrides exist, but this entityClassName isn't included in them, then don't start a network
        // manager for that bucket. This provides simple bucket exclusion for unit tests.
        if (self.bucketOverrides != nil && [self.bucketOverrides objectForKey:schema.bucketName] == nil) {
            continue;
		}
        
		// For websockets, one network manager for all buckets
		if (!self.network) {
			self.network = [SPWebSocketInterface interfaceWithSimperium:self appURL:self.appURL clientID:self.clientID];
		}
		bucket = [[SPBucket alloc] initWithSchema:schema storage:self.coreDataStorage networkInterface:self.network binaryManager:self.binaryManager
							 relationshipResolver:self.relationshipResolver label:self.label];
        
        [bucketList setObject:bucket forKey:schema.bucketName];
    }
    
	[(SPWebSocketInterface *)self.network loadChannelsForBuckets:bucketList overrides:self.bucketOverrides];
    
    return bucketList;
}

- (void)validateObjects {
    for (SPBucket *bucket in [self.buckets allValues]) {
        // Check all existing objects (e.g. in case there are existing ones that aren't in Simperium yet)
        [bucket validateObjects];
    }
    // No need to save, each bucket saves after validation
}

- (void)setAllBucketDelegates:(id)aDelegate {
    for (SPBucket *bucket in [self.buckets allValues]) {
        bucket.delegate = aDelegate;
    }
}

- (void)setRootURL:(NSString *)url {
    _rootURL = [url copy];
    
    self.appURL = [_rootURL stringByAppendingFormat:@"%@/", self.appID];
}

- (void)startWithAppID:(NSString *)identifier APIKey:(NSString *)key {
    DDLogInfo(@"Simperium starting... %@", self.label);
	
	// Enforce required parameters
	NSParameterAssert(identifier);
	NSParameterAssert(key);
	
	// Keep the keys!
    self.appID = identifier;
    self.APIKey = key;
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

- (void)startWithAppID:(NSString *)identifier APIKey:(NSString *)key model:(NSManagedObjectModel *)model context:(NSManagedObjectContext *)context coordinator:(NSPersistentStoreCoordinator *)coordinator {
	DDLogInfo(@"Simperium starting... %@", self.label);
	
	// Enforce required parameters
	NSParameterAssert(identifier);
	NSParameterAssert(key);
	NSParameterAssert(model);
	NSParameterAssert(context);
	NSParameterAssert(coordinator);
	
	NSAssert((context.concurrencyType == NSMainQueueConcurrencyType), NSLocalizedString(@"Error: you must initialize your context with 'NSMainQueueConcurrencyType' concurrency type.", nil));
	NSAssert((context.persistentStoreCoordinator == nil), NSLocalizedString(@"Error: NSManagedObjectContext's persistentStoreCoordinator must be nil. Simperium will handle CoreData connections for you.", nil));
	
	// Keep the keys!
    self.appID = identifier;
    self.APIKey = key;
    self.rootURL = SPBaseURL;
    
    // Setup Core Data storage
    SPCoreDataStorage *storage = [[SPCoreDataStorage alloc] initWithModel:model mainContext:context coordinator:coordinator];
    self.coreDataStorage = storage;
    self.coreDataStorage.delegate = self;
    
	// Setup BinaryManager
	SPBinaryManager *binary = [[SPBinaryManager alloc] initWithSimperium:self];
	self.binaryManager = binary;
	
    // Get the schema from Core Data    
    NSArray *schemas = [self.coreDataStorage exportSchemas];
    
    // Load but don't start yet
    self.buckets = [self loadBuckets:schemas];
    
    // Each NSManagedObject stores a reference to the bucket in which it's stored
    [self.coreDataStorage setBucketList: self.buckets];
    
    // Load metadata for pending references among objects
    [self.relationshipResolver loadPendingRelationships:self.coreDataStorage];
    
    // With everything configured, all objects can now be validated. This will pick up any objects that aren't yet
    // known to Simperium (for the case where you're adding Simperium to an existing app).
    [self validateObjects];
                            
    if (self.authenticationEnabled) {
        [self authenticateIfNecessary];
    }    
}

#pragma mark SPStorageObserver
	
- (BOOL)objectsShouldSync {
    // TODO: rename or possibly (re)move this
    return !self.skipContextProcessing;
}

- (void)storage:(id<SPStorageProvider>)storage updatedObjects:(NSSet *)updatedObjects insertedObjects:(NSSet *)insertedObjects deletedObjects:(NSSet *)deletedObjects {
    // This is automatically called by an SPStorage instance when data is locally changed and then saved

    // First deal with stashed objects (which are known to need a sync)
    NSMutableSet *unsavedObjects = [[storage stashedObjects] copy];

    // Unstash since they're about to be sent
    [storage unstashUnsavedObjects];
    
    for (id<SPDiffable>object in unsavedObjects) {
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

- (BOOL)save {
    [self.JSONStorage save];
    [self.coreDataStorage save];
    return YES;
}

- (void)forceSyncWithTimeout:(NSTimeInterval)timeoutSeconds completion:(SimperiumForceSyncCompletion)completion {
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
		if (!notified) {
			completion(YES);
			notified = YES;
		}
	});
	
	// Notify anyways after timeout
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeoutSeconds * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
		if (!notified) {
			completion(NO);
			notified = YES;
		}
    });
}

- (BOOL)saveWithoutSyncing {
    self.skipContextProcessing = YES;
    BOOL result = [self save];
    self.skipContextProcessing = NO;
    return result;
}

- (void)signOutAndRemoveLocalData:(BOOL)remove {
    DDLogInfo(@"Simperium clearing local data...");
    
    // Reset Simperium
    [self stopNetworking];
    
    // Reset the network manager and processors; any enqueued tasks will get skipped
    for (SPBucket *bucket in [self.buckets allValues]) {
        [bucket unloadAllObjects];
        
        // This will block until everything is all clear
        [bucket.network resetBucketAndWait:bucket];
    }
    
    // Now delete all local content; no more changes will be coming in at this point
    if (remove) {
        self.skipContextProcessing = YES;
        for (SPBucket *bucket in [self.buckets allValues]) {
            [bucket deleteAllObjects];
        }
        self.skipContextProcessing = NO;
    }
    
	// Reset the binary manager!
	[self.binaryManager reset];
	
    // Clear the token and user
    [self.authenticator reset];
    self.user = nil;

    // Don't start network managers again; expect app to handle that
}

- (NSManagedObjectContext *)managedObjectContext {
    return self.coreDataStorage.mainManagedObjectContext;
}

- (NSManagedObjectContext *)writerManagedObjectContext {
    return self.coreDataStorage.writerManagedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    return self.coreDataStorage.managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    return self.coreDataStorage.persistentStoreCoordinator;
}

- (void)authenticationDidSucceedForUsername:(NSString *)username token:(NSString *)token {    
    // It's now safe to start the network managers
    [self startNetworking];
        
    [self closeAuthViewControllerAnimated:YES];
}

- (void)authenticationDidCancel {
    [self stopNetworking];
    [self.authenticator reset];
    self.user.authToken = nil;
    [self closeAuthViewControllerAnimated:YES];
}

- (void)authenticationDidFail {
    [self stopNetworking];
    [self.authenticator reset];
    self.user.authToken = nil;
    
    if (self.authenticationEnabled) {
        // Delay it a touch to avoid issues with storyboard-driven UIs
        [self performSelector:@selector(delayedOpenAuthViewController) withObject:nil afterDelay:0.1];
	}
}

- (BOOL)authenticateIfNecessary {
    if (!self.networkEnabled || !self.authenticationEnabled)
        return NO;
    
    [self stopNetworking];
    
    return [self.authenticator authenticateIfNecessary];    
}

- (void)delayedOpenAuthViewController {
    [self openAuthViewControllerAnimated:YES];
}

- (BOOL)isAuthVisible {
#if TARGET_OS_IPHONE
    // Login can either be its own root, or the first child of a nav controller if auth is optional
    NSArray *childViewControllers = self.rootViewController.presentedViewController.childViewControllers;
	BOOL isNotNil = (self.authenticationViewController != nil);
	BOOL isRoot = (self.rootViewController.presentedViewController == self.authenticationViewController);
    BOOL isChild = (childViewControllers.count > 0 && childViewControllers[0] == self.authenticationViewController);

    return (isNotNil && (isRoot || isChild));
#else
	return (self.authenticationWindowController != nil && self.authenticationWindowController.window.isVisible);
#endif
}

- (void)openAuthViewControllerAnimated:(BOOL)animated {
#if TARGET_OS_IPHONE
    if ([self isAuthVisible]) {
        return;
	}
	
    SPAuthenticationViewController *loginController =  [[self.authenticationViewControllerClass alloc] init];
    self.authenticationViewController = loginController;
    self.authenticationViewController.authenticator = self.authenticator;
    
    if (!self.rootViewController) {
        UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        self.rootViewController = [window rootViewController];
        NSAssert(self.rootViewController, @"Simperium error: to use built-in authentication, you must configure a rootViewController when you "
										   "initialize Simperium, or call setParentViewControllerForAuthentication:. "
										   "This is how Simperium knows where to present a modal view. See enableManualAuthentication in the "
										   "documentation if you want to use your own authentication interface.");
    }
    
    UIViewController *controller = self.authenticationViewController;
    UINavigationController *navController = nil;
    if (self.authenticationOptional) {
        navController = [[UINavigationController alloc] initWithRootViewController: self.authenticationViewController];
        controller = navController;
    }
    
	[self.rootViewController presentViewController:controller animated:animated completion:nil];
#else
    if (!self.authenticationWindowController) {
        self.authenticationWindowController = [[self.authenticationWindowControllerClass alloc] init];
        self.authenticationWindowController.authenticator = self.authenticator;
        self.authenticationWindowController.optional = self.authenticationOptional;
    }
    
    // Hide the main window and show the auth window instead
    [self.window setIsVisible:NO];    
    [[self.authenticationWindowController window] center];
    [[self.authenticationWindowController window] makeKeyAndOrderFront:self];
#endif
}

- (void)closeAuthViewControllerAnimated:(BOOL)animated {
#if TARGET_OS_IPHONE
    // Login can either be its own root, or the first child of a nav controller if auth is optional
    if ([self isAuthVisible]) {
        [self.rootViewController dismissViewControllerAnimated:animated completion:nil];
	}
    self.authenticationViewController = nil;
#else
    [self.window setIsVisible:YES];
    [[self.authenticationWindowController window] close];
    self.authenticationWindowController = nil;
#endif
}


- (void)shutdown {
	
}


#pragma mark SPSimperiumLoggerDelegate

- (void)handleLogMessage:(NSString*)logMessage {
	if (self.remoteLoggingEnabled) {
		[self.network sendLogMessage:logMessage];
	}
}

@end
