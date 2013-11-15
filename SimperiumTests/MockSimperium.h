//
//  MockSimperium.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 11/12/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import <Simperium/Simperium.h>
#import "MockWebSocketInterface.h"



@interface MockSimperium : Simperium

+ (instancetype)mockSimperium;

- (MockWebSocketInterface*)mockWebSocketInterface;

@end
