//
//  SPBinaryManager+Internals.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/9/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPBinaryManager.h"



#pragma mark ====================================================================================
#pragma mark SPBinaryManager Protected Methods
#pragma mark ====================================================================================

@interface SPBinaryManager (Internals)

-(id)initWithSimperium:(Simperium *)aSimperium;

-(void)downloadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey dataKey:(NSString *)dataKey
				infoKey:(NSString *)infoKey binaryInfo:(NSDictionary *)binaryInfo;

-(void)uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey dataKey:(NSString *)dataKey
			  infoKey:(NSString *)infoKey binaryData:(NSData *)binaryData;

-(void)start;
-(void)stop;
-(void)reset;

@end
