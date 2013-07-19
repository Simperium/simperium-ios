//
//  Simperium.h
//
//  Created by Michael Johnston on 11-02-11.
//  Copyright 2011 Simperium. All rights reserved.
//
//  A simple system for shared state. See http://simperium.com for details.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "SPBucket.h"
#import "SPManagedObject.h"
#import "SPAuthenticationManager.h"
#import "SPUser.h"

@class Simperium;
@class SPBinaryManager;

#if TARGET_OS_IPHONE
@class UIViewController;
#else
@class NSWindow;
#endif

/** Delegate protocol for Simperium system notifications.
 
 You can use this delegate to respond to general events and errors.
 
 If you want explicit callbacks when objects are changed/added/deleted, you can also use SPBucketDelegate in SPBucket.h. Standard Core Data notifications are also generated, allowing you to update a `UITableView` (for example) in your `NSFetchedResultsControllerDelegate`. 
 */
@protocol SimperiumDelegate <NSObject>
@optional
- (void)simperium:(Simperium *)simperium didFailWithError:(NSError *)error;
@end

// The main class through which you access Simperium.
@interface Simperium : NSObject<SPAuthenticationDelegate> {
    SPUser *user;
    NSString *label;
    NSString *appID;
    NSString *APIKey;
    NSString *appURL;
    NSString *clientID;   
    id<SimperiumDelegate> __weak delegate;
    SPBinaryManager *binaryManager;
    SPAuthenticationManager *authManager;
    
#if TARGET_OS_IPHONE
    Class __weak loginViewControllerClass;
#else
    Class __weak authWindowControllerClass;
#endif
}

// Initializes Simperium.
#if TARGET_OS_IPHONE
- (id)initWithRootViewController:(UIViewController *)controller;
#else
- (id)initWithWindow:(NSWindow *)aWindow;
#endif


// Starts Simperium with the given credentials (from simperium.com) and an existing Core Data stack.
- (void)startWithAppID:(NSString *)identifier
				APIKey:(NSString *)key
				 model:(NSManagedObjectModel *)model
		   mainContext:(NSManagedObjectContext *)mainContext
		   coordinator:(NSPersistentStoreCoordinator *)coordinator;

// Save and sync all changed objects. If you're using Core Data, this is just a convenience method
// (you can also just save your context and Simperium will see the changes).
- (BOOL)save;

// Get a particular bucket (which, for Core Data, corresponds to a particular Entity name in your model).
// Once you have a bucket instance, you can set a SPBucketDelegate to react to changes.
- (SPBucket *)bucketForName:(NSString *)name;

// Convenience methods for accessing the Core Data stack.
- (NSManagedObjectContext *)mainManagedObjectContext;
- (NSManagedObjectContext *)writerManagedObjectContext;
- (NSManagedObjectModel *)managedObjectModel;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;


// OTHER

// Clears all locally stored data from the device. Can be used to perform a manual sign out.
- (void)signOutAndRemoveLocalData:(BOOL)remove;

// Shares an object with a particular user's email address (forthcoming).
//- (void)shareObject:(SPManagedObject *)object withEmail:(NSString *)email;

// Alternative to setting delegates on each individual bucket (if you want a single handler
// for everything). If you need to, call this after starting Simperium.
- (void)setAllBucketDelegates:(id<SPBucketDelegate>)aDelegate;

// Opens an authentication interface if necessary.
- (BOOL)authenticateIfNecessary;

// Manually adds a binary file to be tracked by Simperium (forthcoming).
- (NSString *)addBinary:(NSData *)binaryData toObject:(SPManagedObject *)object bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName;
- (void)addBinaryWithFilename:(NSString *)filename toObject:(SPManagedObject *)object bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName;

// Saves without syncing (typically not used).
- (BOOL)saveWithoutSyncing;


// Set this to true if you need to be able to cancel the authentication dialog.
@property (nonatomic) BOOL authenticationOptional;

// A SimperiumDelegate for system callbacks.
@property (nonatomic, weak) id<SimperiumDelegate> delegate;

// Toggle verbose logging.
@property (nonatomic) BOOL verboseLoggingEnabled;

// Enables or disables the network.
@property (nonatomic) BOOL networkEnabled;

// Overrides the built-in authentication flow so you can customize the behavior.
@property (nonatomic) BOOL authenticationEnabled;

// Toggle websockets (should only be done before starting Simperium).
@property (nonatomic) BOOL useWebSockets;

// Returns the currently authenticated Simperium user.
@property (nonatomic,strong) SPUser *user;

// The full URL used to communicate with Simperium.
@property (nonatomic,readonly) NSString *appURL;

// URL to a Simperium server (can be changed to point to a custom installation).
@property (nonatomic,copy) NSString *rootURL;

// A unique ID for this app (configured at simperium.com).
@property (nonatomic,readonly) NSString *appID;

// An access token for this app (generated at simperium.com).
@property (nonatomic, readonly) NSString *APIKey;

// A hashed, unique ID for this client.
@property (nonatomic, readonly, copy) NSString *clientID;

// Set this if for some reason you want to use multiple Simperium instances (e.g. unit testing).
@property (copy) NSString *label;

// You can implement your own subclass of SPLoginViewController (iOS) or
// SPLoginWindowController (OSX) to customize authentication.
#if TARGET_OS_IPHONE
@property (nonatomic, weak) Class loginViewControllerClass;
#else
@property (nonatomic, weak) Class authWindowControllerClass;
#endif

// Optional overrides (used for unit testing).
@property (nonatomic, copy) NSDictionary *bucketOverrides;

@property (nonatomic, strong) SPBinaryManager *binaryManager;

@property (nonatomic, strong) SPAuthenticationManager *authManager;


#if TARGET_OS_IPHONE
@property (nonatomic, weak) UIViewController *rootViewController;
#else
@property (nonatomic, weak) NSWindow *window;
#endif

@end
