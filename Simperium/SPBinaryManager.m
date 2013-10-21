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

#warning TODO: Resume on app relaunch
#warning TODO: Handle logouts
#warning TODO: Add retry mechanisms
#warning TODO: What happens if upload finishes, the field gets sync'ed (and download begins), and then the localMetadata gets synced?


#pragma mark ====================================================================================
#pragma mark Notifications
#pragma mark ====================================================================================

NSString* const SPBinaryManagerBucketNameKey		= @"SPBinaryManagerBucketNameKey";
NSString* const SPBinaryManagerSimperiumKey			= @"SPBinaryManagerSimperiumKey";
NSString* const SPBinaryManagerAttributeDataKey		= @"SPBinaryManagerAttributeDataKey";
NSString* const SPBinaryManagerLengthKey			= @"content-length";
NSString* const SPBinaryManagerHashKey				= @"hash";


#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString* const SPBinaryManagerInfoFilename	= @"BinaryMetadata.plist";
static NSString* const SPBinaryManagerTokenKey		= @"X-Simperium-Token";
static NSInteger const SPBinaryManagerSuccessCode	= 200;

static int ddLogLevel = LOG_LEVEL_INFO;


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPBinaryManager()
@property (nonatomic, strong, readwrite) NSMutableDictionary *localBinaryMetadata;
@property (nonatomic, weak,   readwrite) Simperium *simperium;

-(NSString *)binaryMetadataPath;

-(void)loadLocalBinaryMetadata;
-(void)saveLocalBinaryMetadata;

-(NSURL *)remoteUrlForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey;

-(BOOL)shouldDownload:(NSURL *)remoteURL binaryInfo:(NSDictionary *)binaryInfo;
-(BOOL)shouldUpload:(NSURL *)remoteURL binaryData:(NSData *)binaryData;
@end


#pragma mark ====================================================================================
#pragma mark SPBinaryManager
#pragma mark ====================================================================================

@implementation SPBinaryManager

-(id)initWithSimperium:(Simperium *)aSimperium
{
    if (self = [super init]) {
        self.simperium = aSimperium;
		[self loadLocalBinaryMetadata];
    }
    
    return self;
}


#pragma mark ====================================================================================
#pragma mark Persistance Helpers
#pragma mark ====================================================================================

-(NSString *)binaryMetadataPath
{
	return [[NSFileManager binaryDirectory] stringByAppendingPathComponent:SPBinaryManagerInfoFilename];
}

-(void)loadLocalBinaryMetadata
{
	NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
	NSDictionary *persisted = [[NSDictionary alloc] initWithContentsOfFile:self.binaryMetadataPath];
	if (persisted.count) {
		[metadata setValuesForKeysWithDictionary:persisted];
	}
	
	self.localBinaryMetadata = metadata;
}

-(void)saveLocalBinaryMetadata
{
	[self.localBinaryMetadata writeToFile:self.binaryMetadataPath atomically:NO];
}


#pragma mark ====================================================================================
#pragma mark Protected Methods: Download
#pragma mark ====================================================================================

-(void)downloadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey dataKey:(NSString *)dataKey
				infoKey:(NSString *)infoKey binaryInfo:(NSDictionary *)binaryInfo
{
	// Is Simperium authenticated?
	if(self.simperium.user.authenticated == NO) {
		return;
	}
	
	// We're not already in sync, right?
	NSURL *url = [self remoteUrlForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];
	if([self shouldDownload:url binaryInfo:binaryInfo] == NO) {
		return;
	}
	
	// Prepare the request
	SPHttpRequest *request = [SPHttpRequest requestWithURL:url method:SPHttpRequestMethodsGet];
	
	request.headers = @{
		SPBinaryManagerTokenKey : self.simperium.user.authToken
	};
	
	request.userInfo = @{
		SPBinaryManagerBucketNameKey	: bucketName,
		SPBinaryManagerSimperiumKey		: simperiumKey,
		SPBinaryManagerAttributeDataKey	: dataKey,
		SPBinaryManagerLengthKey		: binaryInfo[SPBinaryManagerLengthKey],
		SPBinaryManagerHashKey			: binaryInfo[SPBinaryManagerHashKey]
	};
	
	request.delegate = self;
	request.selectorStarted = @selector(downloadStarted:);
	request.selectorProgress = @selector(downloadProgress:);
	request.selectorSuccess = @selector(downloadSuccess:);
	request.selectorFailed = @selector(downloadFailed:);
	
	// Cancel previous requests with the same URL
	[[SPHttpRequestQueue sharedInstance] cancelRequestsWithURL:url];
	
	// Go!
	[[SPHttpRequestQueue sharedInstance] enqueueHttpRequest:request];
}

-(void)downloadStarted:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium downloading binary at URL: %@", request.url);
	
	if( [self.delegate respondsToSelector:@selector(binaryDownloadStarted:)] ) {
		[self.delegate binaryDownloadStarted:request.userInfo];
	}
}

-(void)downloadProgress:(SPHttpRequest *)request
{
	float progress = [request.userInfo[SPBinaryManagerLengthKey] floatValue] / (request.response.length * 1.0f);
	DDLogWarn(@"Simperium downloaded [%f%%] of [%@]", progress, request.url);
	
	if( [self.delegate respondsToSelector:@selector(binaryDownloadProgress:progress:)] ) {
		[self.delegate binaryDownloadProgress:request.userInfo progress:progress];
	}
}

-(void)downloadFailed:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium error [%@] while downloading binary at URL: %@", request.error, request.url);
	
	if( [self.delegate respondsToSelector:@selector(binaryDownloadFailed:error:)] ) {
		[self.delegate binaryDownloadFailed:request.userInfo error:request.error];
	}
}

-(void)downloadSuccess:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium successfully downloaded binary at URL: %@", request.url);
	
	// Unwrap Params
	NSString *bucketName	= request.userInfo[SPBinaryManagerBucketNameKey];
	NSString *simperiumKey	= request.userInfo[SPBinaryManagerSimperiumKey];
	NSString *dataKey		= request.userInfo[SPBinaryManagerAttributeDataKey];
	
	// The object wasn't deleted, right?
	SPManagedObject *object = [[self.simperium bucketForName:bucketName] objectForKey:simperiumKey];
	if(!object) {
		return;
	}
	
	// Update the local binary
	[object setValue:request.response forKey:dataKey];
	[self.simperium save];
	
	// Update the local metadata. Remote metadata is already up to date!
	NSDictionary *binaryInfo = @{
		SPBinaryManagerHashKey : request.userInfo[SPBinaryManagerHashKey],
		SPBinaryManagerLengthKey : request.userInfo[SPBinaryManagerLengthKey]
	};
	
	[self.localBinaryMetadata setValue:binaryInfo forKey:request.url.absoluteString];
	[self saveLocalBinaryMetadata];
	
	// Notify the delegate (!)
	if( [self.delegate respondsToSelector:@selector(binaryDownloadSuccessful:)] ) {
		[self.delegate binaryDownloadSuccessful:request.userInfo];
	}
}


#pragma mark ====================================================================================
#pragma mark Protected Methods: Upload
#pragma mark ====================================================================================

-(void)uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey dataKey:(NSString *)dataKey
			  infoKey:(NSString *)infoKey binaryData:(NSData *)binaryData
{
//	// Is Simperium authenticated?
//	if(self.simperium.user.authenticated == NO) {
//		return;
//	}
//	
//	// We're not already in sync, right?
//	NSURL *url = [self remoteUrlForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];
//	if([self shouldUpload:url binaryData:binaryData] == NO) {
//		return;
//	}
//	
//	// Wrap up parameters
//	NSDictionary *callbackDict = @{
//									SPBinaryManagerBucketNameKey		: bucketName,
//									SPBinaryManagerSimperiumKey			: simperiumKey,
//									SPBinaryManagerAttributeDataKey		: dataKey,
//									SPBinaryManagerLengthKey			: @(binaryData.length)
//								 };
//
//	// Prepare the request
//	__weak ASIHTTPRequest *request = [self requestWithURL:url];
//	
//	request.requestMethod = @"PUT";
//	request.validatesSecureCertificate = NO;
//
//	request.startedBlock = ^{
//		DDLogWarn(@"Simperium starting binary upload to URL: %@", url);
//		
//		if( [self.delegate respondsToSelector:@selector(binaryUploadStarted:)] ) {
//			[self.delegate binaryUploadStarted:callbackDict];
//		}
//	};
//	
//	request.uploadSizeIncrementedBlock = ^(long long size) {
//		if( [self.delegate respondsToSelector:@selector(binaryUploadProgress:increment:)] ) {
//			[self.delegate binaryUploadProgress:callbackDict increment:size];
//		}
//	};
//	
//	request.completionBlock = ^{
//		if(request.responseStatusCode != SPBinaryManagerSuccessCode) {
//			DDLogError(@"Simperium encountered error %d while trying to upload binary: %@",
//					   request.responseStatusCode, request.responseStatusMessage);
//			return;
//		}
//		
//		// Update the local metadata
//		NSDictionary *binaryInfo = [request.responseString objectFromJSONString];
//		[self.localBinaryMetadata setValue:binaryInfo forKey:url.absoluteString];
//		[self saveLocalBinaryMetadata];
//		
//		// Hit the delegate
//		DDLogWarn(@"Simperium successfully uploaded binary to URL: %@. Response: %@", url, binaryInfo);
//		
//		if( [self.delegate respondsToSelector:@selector(binaryDownloadSuccessful:)] ) {
//			[self.delegate binaryDownloadSuccessful:callbackDict];
//		}
//	};
//	
//	request.failedBlock = ^{
//		DDLogWarn(@"Simperium error [%@] while uploading binary to URL: %@", request.error, url);
//		
//		if( [self.delegate respondsToSelector:@selector(binaryUploadFailed:error:)] ) {
//			[self.delegate binaryUploadFailed:callbackDict error:request.error];
//		}
//	};
//	
//	[request appendPostData:binaryData];
//	
//	// Cancel previous requests!
//	[self cancelRequestsWithURL:url];
//	
//	// Go go go go go!
//	DDLogWarn(@"Simperium uploading binary to URL: %@", url);
//	[request startAsynchronous];
}


#pragma mark ====================================================================================
#pragma mark Private Helpers
#pragma mark ====================================================================================

-(NSURL *)remoteUrlForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey
{
	// NOTE: downloadURL should hit the attribute with 'Info' ending!
	//		[Base URL] / [App ID] / [Bucket Name] / i / [Simperium Key] / b / [attributeName]Info
	NSString* url = [SPBaseURL stringByAppendingFormat:@"%@/%@/i/%@/b/%@", self.simperium.appID, bucketName.lowercaseString, simperiumKey, infoKey];
	return [NSURL URLWithString:url];
}

-(BOOL)shouldDownload:(NSURL *)remoteURL binaryInfo:(NSDictionary *)binaryInfo
{
	NSDictionary *localInfo = self.localBinaryMetadata[remoteURL.absoluteString];
	return (localInfo == nil || [localInfo[SPBinaryManagerHashKey] isEqual:binaryInfo[SPBinaryManagerHashKey]] == NO);
}

-(BOOL)shouldUpload:(NSURL *)remoteURL binaryData:(NSData *)binaryData
{
	NSDictionary *localInfo = self.localBinaryMetadata[remoteURL.absoluteString];
	
	// Speed speed: if the length itself is different, don't even check the hash
	if(localInfo == nil || [localInfo[SPBinaryManagerLengthKey] unsignedIntegerValue] != binaryData.length) {
		return YES;
	// Hash..!
	} else {
		NSString *binaryHash = [NSString sp_md5StringFromData:binaryData];
		return ([localInfo[SPBinaryManagerHashKey] isEqualToString:binaryHash] == NO);
	}
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
