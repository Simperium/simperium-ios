//
//  SPMasterViewController.h
//  Simplestat
//
//  Created by Simplestat on 4/5/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SPDetailViewController;

#import <CoreData/CoreData.h>

@interface SPMasterViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) SPDetailViewController *detailViewController;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
