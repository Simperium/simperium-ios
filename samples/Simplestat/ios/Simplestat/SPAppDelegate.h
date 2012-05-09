//
//  SPAppDelegate.h
//  Simplestat
//
//  Created by Simplestat on 4/5/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Simperium/Simperium.h>

@interface SPAppDelegate : UIResponder <UIApplicationDelegate, SimperiumDelegate>


@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;




- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;


@property (strong, nonatomic) Simperium *simperium;

@end
