//
//  Simperium.h
//
//  Created by Michael Johnston on 11-02-11.
//  Copyright 2011 Simperium. All rights reserved.
//
//  A simple system for shared state. See http://simperium.com for details.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SPManagedObject;
@class SPUser;
@class SPBinaryManager;
@class SPBucket;

#if TARGET_OS_IPHONE
@class UIViewController;
#else
@class NSWindow;
#endif

/** Delegate protocol for sync notifications.
 
 You can use SimperiumDelegate if you want explicit callbacks when entities are changed or added. Standard Core Data notifications are also generated, allowing you to update a `UITableView` (for example) in your `NSFetchedResultsControllerDelegate`. 
 */

@protocol SimperiumDelegate <NSObject>
@optional
-(void)indexingWillStart:(NSString *)entityName;
-(void)indexingDidFinish:(NSString *)entityName;
-(void)authenticationSuccessful;
-(void)authenticationFailed;
-(void)authenticationCanceled;
-(void)lightweightMigrationPerformed;

// The following will be replaced by NSNotifications in a forthcoming version of the API
-(void)receivedObjectForKey:(NSString *)key version:(NSString *)version data:(NSDictionary *)data;
-(void)objectKeysChanged:(NSSet *)keyArray entityName:(NSString *)entityName;
-(void)objectKeysAdded:(NSSet *)keyArray entityName:(NSString *)entityName;
-(void)objectKeyAcknowledged:(NSString *)key entityName:(NSString *)entityName;
-(void)objectKeyWillBeDeleted:(NSString *)key entityName:(NSString *)entityName;
-(void)objectKeysWillChange:(NSSet *)keyArray entityName:(NSString *)entityName;

@end

// The main class through which you access Simperium.
@interface Simperium : NSObject {
    SPUser *user;
    NSString *label;
    NSString *appID;
    NSString *APIKey;
    NSString *appURL;
    NSString *clientID;
    
    SPBinaryManager *binaryManager;
    NSDictionary *bucketOverrides;
    
#if TARGET_OS_IPHONE
    UIViewController *rootViewController;
#else
    NSWindow *window;
#endif
}

// Init
#if TARGET_OS_IPHONE
-(id)initWithRootViewController:(UIViewController *)controller;
#else
-(id)initWithWindow:(NSWindow *)aWindow;
#endif


// CORE DATA API
// Initializes Simperium with the given delegate.

// Starts Simperium with the given application name, access key, and an existing Core Data stack.
-(void)startWithAppID:(NSString *)identifier
               APIKey:(NSString *)key
                model:(NSManagedObjectModel *)model
              context:(NSManagedObjectContext *)context
          coordinator:(NSPersistentStoreCoordinator *)coordinator;

// Save and sync all changed objects; this is optional (saving your context directly will do the same thing).
-(BOOL)save;

// Returns an object that has the specified simperiumKey.
-(SPManagedObject *)objectForKey:(NSString *)key entityName:(NSString *)entityName;

// Retrieve past versions of data for a particular object.
-(void)getVersions:(int)numVersions forObject:(SPManagedObject *)object;

// Returns an array of objects for the specified sync keys.
-(NSArray *)objectsForKeys:(NSSet *)keys entityName:(NSString *)entityName;

// Returns an array containing all instances of a particular entity.
-(NSArray *)objectsForEntityName:(NSString *)entityName;

// Efficiently returns the number of objects for a particular entity.
-(NSInteger)numObjectsForEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate;

// Shares an object with a particular user's email address (not yet ready for production use)
-(void)shareObject:(SPManagedObject *)object withEmail:(NSString *)email bucketName:(NSString *)bucketName;


// OTHER

// Set verbose logging on and off for debugging
-(void)setVerboseLoggingEnabled:(BOOL)on;

// Opens an authentication interface if necessary.
-(BOOL)authenticateIfNecessary;

// Enables or disables the network.
-(void)setNetworkEnabled:(BOOL)enabled;

// Overrides the built-in authentication flow so you can customize the behavior.
-(void)enableManualAuthentication;
-(void)setAuthenticationEnabled:(BOOL)enabled;

// Clears all locally stored data from the device. Can be used to perform a manual sign out.
-(void)clearLocalData;

// Adds a delegate so it will be sent notification callbacks.
-(void)addDelegate:(id)delegate;

// Removes a delegate so it no longer receives notification callbacks.
-(void)removeDelegate:(id)delegate;

/// Optional overrides
-(NSString *)bucketOverrideForEntityName:(NSString *)entityName;
-(void)setBucketOverrides:(NSDictionary *)bucketOverrides;



// Returns the currently authenticated Simperium user.
@property (nonatomic,retain) SPUser *user;

#if TARGET_OS_IPHONE
@property (nonatomic, assign) UIViewController *rootViewController;
#else
@property (nonatomic, assign) NSWindow *window;
#endif


/// The full URL used to communicate with Simperium.
@property (nonatomic,readonly) NSString *appURL;

/// A unique ID for this app (configured at simperium.com).
@property (nonatomic,readonly) NSString *appID;

/// An access token for this app (generated at simperium.com)
@property (nonatomic, readonly) NSString *APIKey;

/// A hashed, unique ID for this client.
@property (nonatomic, readonly) NSString *clientID;

/// Set this if for some reason you want to use multiple Simperium instances (e.g. unit testing).
@property (copy) NSString *label;

/// Optional overrides
-(void)setBucketOverrides:(NSDictionary *)bucketOverrides;

/// All the Simperium delegates
@property (nonatomic,assign,readonly) NSMutableSet *delegates;

/// Saves without syncing (typically not used)
-(BOOL)saveWithoutSyncing;

/// Binary file management (not yet supported)
@property (nonatomic, retain) SPBinaryManager *binaryManager;

/// The NSManagedObjectContext used by Simperium.
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;

/// The NSManagedObjectModel used by Simperium.
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;

/// The NSPersistentStoreCoordinator used by Simperium.
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;


@end
