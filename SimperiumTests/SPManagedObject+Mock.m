//
//  SPManagedObject+Mock.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 12/2/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "SPManagedObject+Mock.h"
#import "SPGhost.h"
#import "JSONKit+Simperium.h"



#pragma mark ====================================================================================
#pragma mark SPManagedObject + Mock helpers
#pragma mark ====================================================================================

@implementation SPManagedObject (Mock)

- (void)test_simulateGhostData
{
    // Simulate Ghost Data
    NSMutableDictionary *memberData = [self.dictionary mutableCopy];
    SPGhost *dummyGhost             = [[SPGhost alloc] initWithKey:self.simperiumKey memberData:memberData];
    dummyGhost.version              = @"1";
    
    // Setup our fields!
    self.ghost                      = dummyGhost;
    self.ghostData                  = [memberData sp_JSONString];
}

@end
