//
//  SPBinaryManager.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-22.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


@class Simperium;

#pragma mark ====================================================================================
#pragma mark SPBinaryManagerDelegate
#pragma mark ====================================================================================

@protocol SPBinaryManagerDelegate <NSObject>
@optional
-(void)binaryUploadStarted:(NSString *)ghostKey attributeName:(NSString *)attributeName;
-(void)binaryUploadSuccessful:(NSString *)ghostKey attribute:(NSString *)attributeName;
-(void)binaryUploadFailed:(NSString *)ghostKey attributeName:(NSString *)attributeName error:(NSError *)error;
-(void)binaryUploadProgress:(NSString *)ghostKey attributeName:(NSString *)attributeName percent:(float) percent;

-(void)binaryDownloadStarted:(NSString *)ghostKey attributeName:(NSString *)attributeName;
-(void)binaryDownloadSuccessful:(NSString *)ghostKey attributeName:(NSString *)attributeName;
-(void)binaryDownloadFailed:(NSString *)ghostKey attributeName:(NSString *)attributeName error:(NSError *)error;
-(void)binaryDownloadProgress:(NSString *)ghostKey attributeName:(NSString *)attributeName percent:(float)percent;
@end


#pragma mark ====================================================================================
#pragma mark SPBinaryManager
#pragma mark ====================================================================================

@interface SPBinaryManager : NSObject

-(id)initWithSimperium:(Simperium *)aSimperium;

-(void)startDownloadIfNeeded:(NSString *)simperiumKey bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName;

-(void)addDelegate:(id)delegate;
-(void)removeDelegate:(id)delegate;

@end
