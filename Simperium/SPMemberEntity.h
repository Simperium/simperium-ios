//
//  SPMemberEntity.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPMember.h"
#import "SPStorageProvider.h"

@interface SPMemberEntity : SPMember {
    NSString *entityName;
}

@property (nonatomic, copy) NSString *entityName;
@property (assign) id<SPStorageProvider>storage;

@end