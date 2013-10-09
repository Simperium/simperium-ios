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



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString* const SPPendingBinaryDownloads = @"SPPendingBinaryDownloads";
static NSString* const SPPendingBinaryUploads = @"SPPendingBinaryUploads";
static NSString* const SPContentLengthKey = @"content-length";

static int ddLogLevel = LOG_LEVEL_INFO;


#pragma mark ====================================================================================
#pragma mark Callbacks
#pragma mark ====================================================================================

typedef void(^SPBinarySuccess)(NSData *data);
typedef void(^SPBinaryFailure)(NSError *error);
typedef void(^SPBinaryProgress)(float percent);


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPBinaryManager()
@property (nonatomic, strong, readwrite) NSMutableDictionary *pendingBinaryDownloads;
@property (nonatomic, strong, readwrite) NSMutableDictionary *pendingBinaryUploads;
@property (nonatomic, strong, readwrite) NSMutableDictionary *transmissionProgress;

@property (nonatomic, strong, readwrite) Simperium *simperium;

-(void)loadPendingBinaryDownloads;
-(void)loadPendingBinaryUploads;
-(void)savePendingBinaryDownloads;
-(void)savePendingBinaryUploads;

-(NSURL *)downloadUrlForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey attributeName:(NSString *)attributeName;
-(void)startDownload:(NSURL *)source success:(SPBinarySuccess)success failure:(SPBinaryFailure)failure progress:(SPBinaryProgress)progress;
-(void)startUpload:(NSURL *)target data:(NSData *)data success:(SPBinarySuccess)success failure:(SPBinaryFailure)failure progress:(SPBinaryProgress)progress;
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
	SPManagedObject *object = [[self.simperium bucketForName:bucketName] objectForKey:simperiumKey];
	NSData *localData = [object valueForKey:attributeName];
	NSUInteger remoteLength = [binaryInfo[SPContentLengthKey] unsignedIntegerValue];
		
	// Are we there yet?
	if(localData.length == remoteLength) {
		return;
	}
	 
	// Starting Download: Hit the delegate
	if( [self.delegate respondsToSelector:@selector(binaryDownloadStarted:attributeName:)] ) {
		[self.delegate binaryDownloadStarted:simperiumKey attributeName:attributeName];
	}

	// Prepare the callbacks
	SPBinarySuccess success = ^(NSData *data) {
#warning TODO: Check if the object wasn't changed locally?
#warning TODO: Check if the object wasn't deleted locally!
#warning TODO: localLength should be persisted somehow else. This is not performant
		
		if( [self.delegate respondsToSelector:@selector(binaryDownloadSuccessful:attributeName:)] ) {
			[self.delegate binaryDownloadSuccessful:simperiumKey attributeName:attributeName];
		}
		
		[object setValue:data forKey:attributeName];
		[self.simperium save];
	};
	
	SPBinaryFailure failure = ^(NSError *error) {
		if( [self.delegate respondsToSelector:@selector(binaryDownloadFailed:attributeName:error:)] ) {
			[self.delegate binaryDownloadFailed:simperiumKey attributeName:attributeName error:error];
		}
	};
	
	SPBinaryProgress progress = ^(float percent) {
		if( [self.delegate respondsToSelector:@selector(binaryDownloadProgress:attributeName:percent:)] ) {
			[self.delegate binaryDownloadProgress:simperiumKey attributeName:attributeName percent:percent];
		}
	};
	
	// Download!
	NSURL *sourceURL = [self downloadUrlForBucket:bucketName simperiumKey:simperiumKey attributeName:attributeName];
	[self startDownload:sourceURL success:success failure:failure progress:progress];
}

-(void)uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey attributeName:(NSString *)attributeName binaryData:(NSData *)binaryData
{
#warning TODO: Hook Up CoreData. Detect changes & upload
#warning TODO: What if a local update is performed while a download was in progress?
#warning TODO: Check if object wasn't changed remotely
	
	// Logic:
	//	Local size != remote size?
	//	Download not in progress? <<< WRONG!
	// Proceed with upload

	
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

-(void)startDownload:(NSURL *)source success:(SPBinarySuccess)success failure:(SPBinaryFailure)failure progress:(SPBinaryProgress)progress
{
	DDLogWarn(@"Simperium downloading binary at URL: %@", source);
	
#warning TODO: Download!
#warning TODO: Maintain downloadsQueue
}

-(void)startUpload:(NSURL *)target data:(NSData *)data success:(SPBinarySuccess)success failure:(SPBinaryFailure)failure progress:(SPBinaryProgress)progress
{
	DDLogWarn(@"Simperium uploading binary to URL: %@", target);
	
#warning Upload!
#warning TODO: Maintain uploadsQueue
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
