//
//  SPBinaryManager.m
//  Simperium
//
//  Created by Michael Johnston on 11-11-22.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "Simperium.h"
#import "SPBinaryManager.h"
#import "SPUser.h"
#import "SPEnvironment.h"
#import "SPManagedObject.h"
#import "SPGhost.h"
#import "NSString+Simperium.h"
#import "JSONKit.h"
#import "DDLog.h"
#import "ASIHTTPRequest.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString* const SPPendingBinaryDownloads = @"SPPendingBinaryDownloads";
static NSString* const SPPendingBinaryUploads = @"SPPendingBinaryUploads";

static NSString* const SPContentLengthKey = @"content-length";
static NSString* const SPSimperiumTokenKey = @"X-Simperium-Token";

static int ddLogLevel = LOG_LEVEL_INFO;


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPBinaryManager()
@property (nonatomic, strong, readwrite) NSMutableDictionary *pendingBinaryDownloads;
@property (nonatomic, strong, readwrite) NSMutableDictionary *pendingBinaryUploads;
@property (nonatomic, strong, readwrite) NSMutableDictionary *transmissionProgress;

@property (nonatomic, weak, readwrite) Simperium *simperium;

-(void)loadPendingBinaryDownloads;
-(void)loadPendingBinaryUploads;
-(void)savePendingBinaryDownloads;
-(void)savePendingBinaryUploads;

-(NSURL *)downloadUrlForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey attributeName:(NSString *)attributeName;
@end


#pragma mark ====================================================================================
#pragma mark SPBinaryManager
#pragma mark ====================================================================================

@implementation SPBinaryManager

-(id)initWithSimperium:(Simperium *)aSimperium
{
    if (self = [super init]) {
        self.simperium = aSimperium;
        
        self.pendingBinaryDownloads = [NSMutableDictionary dictionary];
        self.pendingBinaryUploads = [NSMutableDictionary dictionary];
        self.transmissionProgress = [NSMutableDictionary dictionary];
		
        [self loadPendingBinaryDownloads];
        [self loadPendingBinaryUploads];
    }
    
    return self;
}


#pragma mark ====================================================================================
#pragma mark Persistance Helpers
#pragma mark ====================================================================================

-(void)loadPendingBinaryDownloads
{
	NSString *pendingJSON = [[NSUserDefaults standardUserDefaults] objectForKey:SPPendingBinaryDownloads];
    NSDictionary *pendingDict = [pendingJSON objectFromJSONString];
    if (pendingDict.count > 0) {
        [self.pendingBinaryDownloads setValuesForKeysWithDictionary:pendingDict];
	}
}

-(void)loadPendingBinaryUploads
{
	NSString *pendingJSON = [[NSUserDefaults standardUserDefaults] objectForKey:SPPendingBinaryUploads];
    NSDictionary *pendingDict = [pendingJSON objectFromJSONString];
    if (pendingDict.count > 0) {
        [self.pendingBinaryUploads setValuesForKeysWithDictionary:pendingDict];
	}
}

-(void)savePendingBinaryDownloads
{
    NSString *json = [self.pendingBinaryDownloads JSONString];
	[[NSUserDefaults standardUserDefaults] setObject:json forKey:SPPendingBinaryDownloads];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)savePendingBinaryUploads
{
    NSString *json = [self.pendingBinaryUploads JSONString];
	[[NSUserDefaults standardUserDefaults] setObject:json forKey:SPPendingBinaryUploads];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


#pragma mark ====================================================================================
#pragma mark Protected Methods
#pragma mark ====================================================================================

-(void)downloadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey attributeName:(NSString *)attributeName binaryInfo:(NSDictionary *)binaryInfo
{
#warning FIX CRASH when binaryInfo != NSDictionary!!!
#warning TODO: localLength should be persisted somehow else. This is not performant
#warning TODO: What if a remote change comes in, while there was another download/upload?  >> CANCEL previous download/upload!
#warning TODO: What if a remote change comes in, and the object was locally changed but not saved?
#warning TODO: 'dataName' This is ugly. Seriously
#warning TODO: Maintain downloadsQueue
	
	SPManagedObject *object = [[self.simperium bucketForName:bucketName] objectForKey:simperiumKey];
	NSData *localData = [object valueForKey:attributeName];
	NSUInteger remoteLength = [binaryInfo[SPContentLengthKey] unsignedIntegerValue];
		
	// Are we there yet?
	if(localData.length == remoteLength) {
		return;
	}

	NSString *dataName = [attributeName stringByReplacingOccurrencesOfString:@"Info" withString:@"Data"];

	// Starting Download: Hit the delegate
	if( [self.delegate respondsToSelector:@selector(binaryDownloadStarted:attributeName:)] ) {
		[self.delegate binaryDownloadStarted:simperiumKey attributeName:attributeName];
	}
	
	NSURL *sourceURL = [self downloadUrlForBucket:bucketName simperiumKey:simperiumKey attributeName:attributeName];
	
	// Start Download: Go go go go!
	__weak ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:sourceURL];
	
	request.requestHeaders = [@{ SPSimperiumTokenKey : self.simperium.user.authToken } mutableCopy];
	
	request.completionBlock = ^{
		// The object wasn't deleted, right?
		SPManagedObject *object = [[self.simperium bucketForName:bucketName] objectForKey:simperiumKey];
		if(!object) {
			return;
		}
		
		[object setValue:request.responseData forKey:dataName];
		[self.simperium save];
		
		if( [self.delegate respondsToSelector:@selector(binaryDownloadSuccessful:attributeName:)] ) {
			[self.delegate binaryDownloadSuccessful:simperiumKey attributeName:attributeName];
		}
	};
	
	request.failedBlock = ^{
		NSError *error = request.error;
		DDLogWarn(@"Simperium error [%@] while downloading binary at URL: %@", error, sourceURL);
		
		if( [self.delegate respondsToSelector:@selector(binaryDownloadFailed:attributeName:error:)] ) {
			[self.delegate binaryDownloadFailed:simperiumKey attributeName:attributeName error:request.error];
		}
	};
	
	request.downloadSizeIncrementedBlock = ^(long long size) {
		if( [self.delegate respondsToSelector:@selector(binaryDownloadProgress:attributeName:percent:)] ) {
			float percent = size * 1.0f / remoteLength * 1.0f;
			[self.delegate binaryDownloadProgress:simperiumKey attributeName:attributeName percent:percent];
		}
	};
	
	DDLogWarn(@"Simperium downloading binary at URL: %@", sourceURL);
	[request startAsynchronous];
}

-(void)uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey attributeName:(NSString *)attributeName binaryData:(NSData *)binaryData
{
#warning TODO: Hook Up CoreData. Problem: how to detect if a binary field was just locally updated.
#warning TODO: What if a local change is performed while a download/upload was in progress?	>> CANCEL previous download/upload if any!!
#warning TODO: Upload!
#warning TODO: Maintain uploadsQueue
	
	// Logic:
	//	Local size != remote size?
	//	Download not in progress? <<< WRONG!
	// Proceed with upload
	
//	DDLogWarn(@"Simperium uploading binary to URL: %@", target);
}


#pragma mark ====================================================================================
#pragma mark Private Methods
#pragma mark ====================================================================================

-(NSURL *)downloadUrlForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey attributeName:(NSString *)attributeName
{
	// NOTE: downloadURL should hit the attribute with 'Info' ending!
	// [Base URL] / [App ID] / [Bucket Name] / i / [Simperium Key] / b / [attributeName]Info
	NSString *rawURL = [SPBaseURL stringByAppendingFormat:@"%@/%@/i/%@/b/%@", self.simperium.appID, bucketName.lowercaseString, simperiumKey, attributeName];
	return [NSURL URLWithString:rawURL];
}


#pragma mark ====================================================================================
#pragma mark Static Helpers
#pragma mark ====================================================================================

+(int)ddLogLevel
{
    return ddLogLevel;
}

+(void)ddSetLogLevel:(int)logLevel
{
    ddLogLevel = logLevel;
}


#pragma mark ====================================================================================
#pragma mark LEGACY!
#pragma mark ====================================================================================

#warning TODO Nuke once ready!

//-(void)startUploading:(NSString *)filename
//{
//    
//	//    UIApplication *app = [UIApplication sharedApplication];
//	//    UIBackgroundTaskIdentifier tempBgTask = [app beginBackgroundTaskWithExpirationHandler:^{
//	//
//	//        NSLog(@"Expired Upload for %@.",filename);
//	//        [app endBackgroundTask:[[self.bgTasks objectForKey:filename] intValue]];
//	//        [self.bgTasks setObject:[NSNumber numberWithInt:UIBackgroundTaskInvalid] forKey:filename];
//	//
//	//    }];
//	//
//	//    [self.bgTasks setObject:[NSNumber numberWithInt: tempBgTask] forKey:filename];
//
//    UIBackgroundTaskIdentifier bgTask = [[self.bgTasks objectForKey:request.key] intValue];
//    if (bgTask != UIBackgroundTaskInvalid) {
//        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
//        bgTask = UIBackgroundTaskInvalid;
//        [self.bgTasks setObject:[NSNumber numberWithInt: UIBackgroundTaskInvalid] forKey:request.key];
//    }
//    


@end
