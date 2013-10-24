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
#import "JSONKit.h"
#import "DDLog.h"
#import "NSFileManager+Simperium.h"
#import "NSString+Simperium.h"

#import "SPHttpRequest.h"
#import "SPHttpRequestQueue.h"


#warning TODO: Don't upload if local mtime < remoteMtime
#warning TODO: Add retry mechanisms
#warning TODO: Should Nulls be actually uploaded?
#warning TODO: What if a remote change comes in, and the object was locally changed but not saved?
#warning TODO: Disable Logs

#pragma mark ====================================================================================
#pragma mark Notifications
#pragma mark ====================================================================================

NSString* const SPBinaryManagerBucketNameKey				= @"SPBinaryManagerBucketNameKey";
NSString* const SPBinaryManagerSimperiumKey					= @"SPBinaryManagerSimperiumKey";
NSString* const SPBinaryManagerAttributeDataKey				= @"SPBinaryManagerAttributeDataKey";
NSString* const SPBinaryManagerAttributeInfoKey				= @"SPBinaryManagerAttributeInfoKey";
NSString* const SPBinaryManagerOperation					= @"SPBinaryManagerOperation";
NSString* const SPBinaryManagerHashKey						= @"hash";
NSString* const SPBinaryManagerModificationTimeKey			= @"mtime";


#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString* const SPBinaryManagerMetadataFilename		= @"BinaryMetadata.plist";
static NSString* const SPBinaryManagerPendingSyncsFilename	= @"PendingSyncs.plist";
static NSString* const SPBinaryManagerTokenKey				= @"X-Simperium-Token";

NS_ENUM(NSInteger, SPBinaryManagerOperations) {
	SPBinaryManagerOperationsDownload,
	SPBinaryManagerOperationsUpload
};

static int ddLogLevel = LOG_LEVEL_WARN;


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPBinaryManager()
@property (nonatomic, strong, readwrite) SPHttpRequestQueue *httpRequestsQueue;
@property (nonatomic, strong, readwrite) dispatch_queue_t binaryManagerQueue;
@property (nonatomic, weak,   readwrite) Simperium *simperium;

@property (nonatomic, strong, readwrite) NSMutableDictionary *localMetadata;
@property (nonatomic, strong, readwrite) NSMutableDictionary *activeUploads;
@property (nonatomic, strong, readwrite) NSMutableDictionary *activeDownloads;
@property (nonatomic, assign, readwrite) BOOL didResumeSyncs;

-(NSString *)pendingSyncsPath;
-(void)resumePendingSyncs;
-(void)resumePendingSync:(NSDictionary *)syncInfo;
-(void)savePendingSyncs;

-(NSString *)localMetadataPath;
-(void)loadLocalMetadata;
-(void)saveLocalMetadata;

-(SPHttpRequest *)requestForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey;
@end


#pragma mark ====================================================================================
#pragma mark SPBinaryManager
#pragma mark ====================================================================================

@implementation SPBinaryManager

-(id)initWithSimperium:(Simperium *)aSimperium
{
    if (self = [super init]) {
		// We'll need this one!
        self.simperium = aSimperium;
		
		// Wrap up local ops in a GCD queue
		self.binaryManagerQueue = dispatch_queue_create("com.simperium.SPBinaryManager", NULL);
	
		// We'll have our own Http Queue: Multiple Simperium instances shouldn't interfere with each other
		self.httpRequestsQueue = [[SPHttpRequestQueue alloc] init];
		self.httpRequestsQueue.enabled = NO;
		
		// Active Upload/Download: simperiumKey >> hash
		self.activeUploads = [NSMutableDictionary dictionary];
		self.activeDownloads = [NSMutableDictionary dictionary];
		
		// Load local metadata
		[self loadLocalMetadata];
    }
    
    return self;
}

-(void)start
{
	self.httpRequestsQueue.enabled = YES;
	[self resumePendingSyncs];
}

-(void)stop
{
	self.httpRequestsQueue.enabled = NO;
}

-(void)reset
{
	// HttpRequest should stop now
	[self.httpRequestsQueue cancelAllRequest];
	
	// Cleanup
	[self.activeDownloads removeAllObjects];
	[self.activeUploads removeAllObjects];
	
	// Reset pending syncs
	self.didResumeSyncs = NO;
	[self savePendingSyncs];
	
	// Nuke local metadata as well
	[self.localMetadata removeAllObjects];
	[self saveLocalMetadata];
}


#pragma mark ====================================================================================
#pragma mark Persistance Helpers: Metadata
#pragma mark ====================================================================================

-(NSString *)pendingSyncsPath
{
	NSString *filename = [NSString stringWithFormat:@"%@%@", self.simperium.label, SPBinaryManagerPendingSyncsFilename];
	return [[NSFileManager binaryDirectory] stringByAppendingPathComponent:filename];
}

-(void)resumePendingSyncs
{
	dispatch_async(self.binaryManagerQueue, ^{
		// Do this just once: performance please!
		if(self.didResumeSyncs) {
			return;
		} else {
			self.didResumeSyncs = YES;
		}
		
		NSArray *pendings = [NSArray arrayWithContentsOfFile:self.pendingSyncsPath];
		for(NSDictionary *userInfo in pendings) {
			[self resumePendingSync:userInfo];
		}
	});
}

-(void)resumePendingSync:(NSDictionary *)syncInfo
{
	// Unwrap Parameters
	NSString *bucketName	= syncInfo[SPBinaryManagerBucketNameKey];
	NSString *simperiumKey	= syncInfo[SPBinaryManagerSimperiumKey];
	NSString *dataKey		= syncInfo[SPBinaryManagerAttributeDataKey];
	NSString *infoKey		= syncInfo[SPBinaryManagerAttributeInfoKey];
	NSNumber *operation		= syncInfo[SPBinaryManagerOperation];
	
	// Download: Just go on
	if(operation.intValue == SPBinaryManagerOperationsDownload)
	{
		[self _downloadIfNeeded:bucketName simperiumKey:simperiumKey dataKey:dataKey infoKey:infoKey binaryInfo:syncInfo];
		return;
	}
	
	// Upload: Retrieve the data from the storage
	id<SPStorageProvider> storage = [[[self.simperium bucketForName:bucketName] storage] threadSafeStorage];
	id<SPDiffable> object = [storage objectForKey:simperiumKey bucketName:bucketName];
	
	if(object) {
		NSData *binaryData = [[object simperiumValueForKey:dataKey] copy];
		[self _uploadIfNeeded:bucketName simperiumKey:simperiumKey dataKey:dataKey infoKey:infoKey binaryData:binaryData];
	}
}

-(void)savePendingSyncs
{
	dispatch_async(self.binaryManagerQueue, ^{

		NSMutableArray *pendingSyncs = [NSMutableArray array];
		for(SPHttpRequest *request in self.httpRequestsQueue.requests) {
			if(request.userInfo && request.status != SPHttpRequestStatusDone) {
				[pendingSyncs addObject:request.userInfo];
			}
		}

		[pendingSyncs writeToFile:self.pendingSyncsPath atomically:YES];
	});
}


#pragma mark ====================================================================================
#pragma mark Persistance Helpers: Metadata
#pragma mark ====================================================================================

-(NSString *)localMetadataPath
{
	NSString *filename = [NSString stringWithFormat:@"%@%@", self.simperium.label, SPBinaryManagerMetadataFilename];
	return [[NSFileManager binaryDirectory] stringByAppendingPathComponent:filename];
}

-(void)loadLocalMetadata
{
	self.localMetadata = [NSMutableDictionary dictionaryWithContentsOfFile:self.localMetadataPath];
}

-(void)saveLocalMetadata
{
	dispatch_async(self.binaryManagerQueue, ^{
		[self.localMetadata writeToFile:self.localMetadataPath atomically:NO];
	});
}


#pragma mark ====================================================================================
#pragma mark Protected Methods: Download
#pragma mark ====================================================================================

-(void)downloadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey dataKey:(NSString *)dataKey
				infoKey:(NSString *)infoKey binaryInfo:(NSDictionary *)binaryInfo
{
	dispatch_async(self.binaryManagerQueue, ^{
		[self _downloadIfNeeded:bucketName simperiumKey:simperiumKey dataKey:dataKey infoKey:infoKey binaryInfo:binaryInfo];
	});
}

-(void)_downloadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey dataKey:(NSString *)dataKey
				infoKey:(NSString *)infoKey binaryInfo:(NSDictionary *)binaryInfo
{
	// Is Simperium authenticated?
	if(!self.simperium.user.authenticated) {
		return;
	}

	// Are we there yet?
	NSDictionary *localMetadata	= self.localMetadata[simperiumKey];
	NSString *localHash			= localMetadata[SPBinaryManagerHashKey];
	NSNumber *localMtime		= localMetadata[SPBinaryManagerModificationTimeKey];
	NSString *remoteHash		= binaryInfo[SPBinaryManagerHashKey];
	NSNumber *remoteMtime		= binaryInfo[SPBinaryManagerModificationTimeKey];

	if ([localHash isEqual:remoteHash] || [self.activeDownloads[simperiumKey] isEqualToString:remoteHash] || self.activeUploads[simperiumKey] != nil) {
		return;
	} else if(localMtime.intValue >= remoteMtime.intValue) {
		return;
	}
	
	// Wrap up the download parameters
	NSDictionary *userInfo = @{
		SPBinaryManagerBucketNameKey		: bucketName,
		SPBinaryManagerSimperiumKey			: simperiumKey,
		SPBinaryManagerAttributeDataKey		: dataKey,
		SPBinaryManagerAttributeInfoKey		: infoKey,
		SPBinaryManagerHashKey				: remoteHash,
		SPBinaryManagerModificationTimeKey	: remoteMtime,
		SPBinaryManagerOperation			: @(SPBinaryManagerOperationsDownload)
	};
		
	// Prepare the request
	SPHttpRequest *request = [self requestForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];
	
	request.method = SPHttpRequestMethodsGet;
	request.userInfo = userInfo;
	
	request.delegate = self;
	request.selectorStarted = @selector(downloadStarted:);
	request.selectorProgress = @selector(downloadProgress:);
	request.selectorSuccess = @selector(downloadSuccess:);
	request.selectorFailed = @selector(downloadFailed:);
	
	// Update: Active + Pendings Syncs
	[self.httpRequestsQueue cancelRequestsWithURL:request.url];
	[self.httpRequestsQueue enqueueHttpRequest:request];
	
	// Update: Active + Pendings Syncs
	[self.activeDownloads setObject:remoteHash forKey:simperiumKey];
	[self savePendingSyncs];
}


#pragma mark ====================================================================================
#pragma mark Private Methods: SPHttpRequest DOWNLOAD delegates
#pragma mark ====================================================================================

-(void)downloadStarted:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium starting binary download from URL: %@", request.url);
	
	if( [self.delegate respondsToSelector:@selector(binaryDownloadStarted:)] ) {
		[self.delegate binaryDownloadStarted:request.userInfo];
	}
}

-(void)downloadProgress:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium downloaded [%.1f%%] of [%@]", request.downloadProgress, request.url);
	
	if( [self.delegate respondsToSelector:@selector(binaryDownloadProgress:progress:)] ) {
		[self.delegate binaryDownloadProgress:request.userInfo progress:request.downloadProgress];
	}
}

-(void)downloadFailed:(SPHttpRequest *)request
{
	DDLogError(@"Simperium error [%@] while downloading binary at URL: %@", request.responseError, request.url);
	
	// Update: Active + Pendings Syncs
	NSString *simperiumKey = request.userInfo[SPBinaryManagerSimperiumKey];
	[self.activeDownloads removeObjectForKey:simperiumKey];
	[self savePendingSyncs];
	
	// Delegates, please!
	if( [self.delegate respondsToSelector:@selector(binaryDownloadFailed:error:)] ) {
		[self.delegate binaryDownloadFailed:request.userInfo error:request.responseError];
	}
}

-(void)downloadSuccess:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium successfully downloaded binary at URL: %@", request.url);
	
	// Unwrap Params
	NSDictionary *userInfo  = request.userInfo;
	NSString *bucketName	= userInfo[SPBinaryManagerBucketNameKey];
	NSString *simperiumKey	= userInfo[SPBinaryManagerSimperiumKey];
	NSString *dataKey		= userInfo[SPBinaryManagerAttributeDataKey];
	
	// Load the object
	SPManagedObject *object = [[self.simperium bucketForName:bucketName] objectForKey:simperiumKey];
	
	if(object) {
		[object setValue:request.responseData forKey:dataKey];
		[self.simperium save];
		
		[self.localMetadata setValue:userInfo forKey:simperiumKey];
	} else {
		[self.localMetadata removeObjectForKey:simperiumKey];
	}

	// Update: Metadata
	[self saveLocalMetadata];
	
	// Update: Pending Syncs
	[self savePendingSyncs];
	
	// Update: Active Syncs
	[self.activeDownloads removeObjectForKey:simperiumKey];
	
	// Notify the delegate (!)
	if( [self.delegate respondsToSelector:@selector(binaryDownloadSuccessful:)] ) {
		[self.delegate binaryDownloadSuccessful:userInfo];
	}
}


#pragma mark ====================================================================================
#pragma mark Protected Methods: Upload
#pragma mark ====================================================================================

-(void)uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey dataKey:(NSString *)dataKey
			  infoKey:(NSString *)infoKey binaryData:(NSData *)binaryData
{
	dispatch_async(self.binaryManagerQueue, ^{
		[self _uploadIfNeeded:bucketName simperiumKey:simperiumKey dataKey:dataKey infoKey:infoKey binaryData:binaryData];
	});
}

-(void)_uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey dataKey:(NSString *)dataKey
			   infoKey:(NSString *)infoKey binaryData:(NSData *)binaryData
{
	// Is Simperium authenticated?
	if(!self.simperium.user.authenticated || !self.simperium.networkEnabled) {
		return;
	}
	
	// Are we there yet?
	NSString *localHash  = [NSString sp_md5StringFromData:binaryData];
	NSString *remoteHash = self.localMetadata[simperiumKey][SPBinaryManagerHashKey];
	
	if ([localHash isEqualToString:remoteHash] || [self.activeUploads[simperiumKey] isEqualToString:localHash]) {
		return;
	}
	
	// Wrap up the Upload parameters
	NSDictionary *userInfo = @{
		SPBinaryManagerBucketNameKey	: bucketName,
		SPBinaryManagerSimperiumKey		: simperiumKey,
		SPBinaryManagerAttributeDataKey	: dataKey,
		SPBinaryManagerAttributeInfoKey	: infoKey,
		SPBinaryManagerHashKey			: localHash,
		SPBinaryManagerOperation		: @(SPBinaryManagerOperationsUpload)
	};
	
	// Prepare the request
	SPHttpRequest *request = [self requestForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];
	
	request.method = SPHttpRequestMethodsPut;
	request.userInfo = userInfo;
	request.postData = binaryData;
	
	request.delegate = self;
	request.selectorStarted = @selector(uploadStarted:);
	request.selectorProgress = @selector(uploadProgress:);
	request.selectorSuccess = @selector(uploadSuccess:);
	request.selectorFailed = @selector(uploadFailed:);
	
	// Cancel previous requests with the same URL & Enqueue this request!
	[self.httpRequestsQueue cancelRequestsWithURL:request.url];
	[self.httpRequestsQueue enqueueHttpRequest:request];
	
	// Update: Active + Pendings Syncs
	[self.activeUploads setObject:localHash forKey:simperiumKey];
	[self savePendingSyncs];
}


#pragma mark ====================================================================================
#pragma mark Private Methods: SPHttpRequest UPLOAD delegates
#pragma mark ====================================================================================

-(void)uploadStarted:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium starting binary upload to URL: %@", request.url);

	if( [self.delegate respondsToSelector:@selector(binaryUploadStarted:)] ) {
		[self.delegate binaryUploadStarted:request.userInfo];
	}
}

-(void)uploadProgress:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium uploaded [%.1f%%] of [%@]", request.uploadProgress, request.url);
	
	if( [self.delegate respondsToSelector:@selector(binaryUploadProgress:progress:)] ) {
		[self.delegate binaryUploadProgress:request.userInfo progress:request.uploadProgress];
	}
}

-(void)uploadFailed:(SPHttpRequest *)request
{
	DDLogError(@"Simperium error [%@] while uploading binary to URL: %@", request.responseError, request.url);

	// Update: Active + Pendings Syncs
	NSString *simperiumKey = request.userInfo[SPBinaryManagerSimperiumKey];
	[self.activeUploads removeObjectForKey:simperiumKey];
	[self savePendingSyncs];
	
	// Delegates, please!
	if( [self.delegate respondsToSelector:@selector(binaryUploadFailed:error:)] ) {
		[self.delegate binaryUploadFailed:request.userInfo error:request.responseError];
	}
}

-(void)uploadSuccess:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium successfully uploaded binary to URL: %@", request.url);
			
	// Unwrap Parameters
	NSDictionary *metadata	= [request.responseString objectFromJSONString];
	NSString *simperiumKey	= request.userInfo[SPBinaryManagerSimperiumKey];

	// Update: Metadata
	[self.localMetadata setValue:metadata forKey:simperiumKey];
	[self saveLocalMetadata];
	
	// Update: Pendings File
	[self savePendingSyncs];
	
	// Update: Active Syncs
	[self.activeUploads removeObjectForKey:simperiumKey];
	
	// Notify the delegate (!)
	if( [self.delegate respondsToSelector:@selector(binaryUploadSuccessful:)] ) {
		[self.delegate binaryUploadSuccessful:request.userInfo];
	}
}


#pragma mark ====================================================================================
#pragma mark Private Helpers
#pragma mark ====================================================================================

-(SPHttpRequest *)requestForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey
{
	// NOTE: downloadURL should hit the attribute with 'Info' ending!
	//		[Base URL] / [App ID] / [Bucket Name] / i / [Simperium Key] / b / [attributeName]Info
	NSString *rawUrl = [SPBaseURL stringByAppendingFormat:@"%@/%@/i/%@/b/%@", self.simperium.appID, bucketName.lowercaseString, simperiumKey, infoKey];
	
	SPHttpRequest *request = [SPHttpRequest requestWithURL:[NSURL URLWithString:rawUrl]];
	request.headers = @{ SPBinaryManagerTokenKey : self.simperium.user.authToken };
	
	return request;
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

@end
