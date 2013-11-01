//
//  SPRemoteLogger.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/31/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPRemoteLogger.h"



#pragma mark ====================================================================================
#pragma mark SPRemoteLogger
#pragma mark ====================================================================================

@implementation SPRemoteLogger

-(id)initWithDelegate:(id<SPRemoteLoggerDelegate>)delegate
{
	if((self = [super init])) {
		self.delegate = delegate;
	}
	return self;
}

-(void)logMessage:(DDLogMessage *)logMessage
{
    NSString *message = (formatter) ? [formatter formatLogMessage:logMessage] : logMessage->logMsg;
	
    if(message && self.delegate) {
		[self.delegate sendLogMessage:message];
	}
}

@end
