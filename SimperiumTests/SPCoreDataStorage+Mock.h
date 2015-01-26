//
//  SPCoreDataStorage+Mock.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 12/2/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPCoreDataStorage.h"



@interface SPCoreDataStorage (Mock)

- (void)test_waitUntilSaveCompletes;
- (void)test_simulateWorkerOnlyMergesChangesIntoWriter;
- (void)test_simulateWorkerCannotMergeChangesAnywhere;

@end
