//
//  SPBinaryManager.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-22.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>


#pragma mark ====================================================================================
#pragma mark SPBinaryManagerDelegate
#pragma mark ====================================================================================

@protocol SPBinaryManagerDelegate <NSObject>
@optional
-(void)binaryUploadStarted:(NSString *)simperiumKey attributeName:(NSString *)attributeName;
-(void)binaryUploadSuccessful:(NSString *)simperiumKey attribute:(NSString *)attributeName;
-(void)binaryUploadFailed:(NSString *)simperiumKey attributeName:(NSString *)attributeName error:(NSError *)error;
-(void)binaryUploadProgress:(NSString *)simperiumKey attributeName:(NSString *)attributeName percent:(float) percent;

-(void)binaryDownloadStarted:(NSString *)simperiumKey attributeName:(NSString *)attributeName;
-(void)binaryDownloadSuccessful:(NSString *)simperiumKey attributeName:(NSString *)attributeName;
-(void)binaryDownloadFailed:(NSString *)simperiumKey attributeName:(NSString *)attributeName error:(NSError *)error;
-(void)binaryDownloadProgress:(NSString *)simperiumKey attributeName:(NSString *)attributeName percent:(float)percent;
@end


#pragma mark ====================================================================================
#pragma mark SPBinaryManager
#pragma mark ====================================================================================

@interface SPBinaryManager : NSObject
@property (nonatomic, weak, readwrite) id<SPBinaryManagerDelegate> delegate;
@end
