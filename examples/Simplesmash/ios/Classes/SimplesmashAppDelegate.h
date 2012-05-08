//
//  SimplesmashAppDelegate.h
//

#import <UIKit/UIKit.h>
#import <Simperium/Simperium.h>

@interface SimplesmashAppDelegate : NSObject <UIApplicationDelegate, SimperiumDelegate> {
	UIWindow *window;
}

@property (nonatomic, retain) UIWindow *window;
@property (strong, nonatomic) Simperium *simperium;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
