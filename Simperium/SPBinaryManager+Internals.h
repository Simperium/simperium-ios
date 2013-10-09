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

-(void)downloadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey attributeName:(NSString *)attributeName binaryInfo:(NSDictionary *)binaryInfo;
-(void)uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey attributeName:(NSString *)attributeName binaryData:(NSData *)binaryData;

@end