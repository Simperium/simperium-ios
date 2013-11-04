//
//  SPRemoteLogger.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/31/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "DDLog.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

NS_ENUM(NSInteger, SPNetworkLogLevels) {
	SPNetworkLogLevelsOff		= 0,
	SPNetworkLogLevelsRegular	= 1,
	SPNetworkLogLevelsVerbose	= 2
};


#pragma mark ====================================================================================
#pragma mark SPRemoteLoggerDelegate
#pragma mark ====================================================================================

@protocol SPRemoteLoggerDelegate <NSObject>
-(void)sendLogMessage:(NSString*)logMessage;
@end


#pragma mark ====================================================================================
#pragma mark SPRemoteLogger
#pragma mark ====================================================================================

@interface SPRemoteLogger : DDAbstractLogger <DDLogger>

@property (nonatomic, weak, readwrite) id<SPRemoteLoggerDelegate> delegate;

-(id)initWithDelegate:(id<SPRemoteLoggerDelegate>)delegate;

@end
