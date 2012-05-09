//
//  SPDetailViewController.h
//  Simplestat
//
//  Created by Simplestat on 4/5/12.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Dashboard;

@interface SPDetailViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) Dashboard *detailItem;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;


@end