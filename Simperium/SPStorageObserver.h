//
//  SPStorageObserver.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-17.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPStorageProvider.h"



#pragma mark ====================================================================================
#pragma mark SPStorageObserver
#pragma mark ====================================================================================

@protocol SPStorageObserver <NSObject>
- (void)storageWillSave:(id<SPStorageProvider>)storage;
- (void)storageDidSave:(id<SPStorageProvider>)storage;
@end
