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

NSString* const SPBinaryManagerBucketNameKey = @"SPBinaryManagerBucketNameKey";
NSString* const SPBinaryManagerSimperiumKey = @"SPBinaryManagerSimperiumKey";
NSString* const SPBinaryManagerAttributeDataKey = @"SPBinaryManagerAttributeDataKey";
NSString* const SPBinaryManagerLengthKey = @"SPBinaryManagerLengthKey";

static NSString* const SPLocalBinaryMetadataKey = @"SPLocalBinaryMetadataKey";
static NSString* const SPPendingBinaryDownloads = @"SPPendingBinaryDownloads";
static NSString* const SPPendingBinaryUploads = @"SPPendingBinaryUploads";

static NSString* const SPContentLengthKey = @"content-length";
static NSString* const SPContentHashKey = @"hash";
static NSString* const SPSimperiumTokenKey = @"X-Simperium-Token";

static int ddLogLevel = LOG_LEVEL_INFO;


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPBinaryManager()
@property (nonatomic, strong, readwrite) NSMutableDictionary *pendingBinaryDownloads;
@property (nonatomic, strong, readwrite) NSMutableDictionary *pendingBinaryUploads;
@property (nonatomic, strong, readwrite) NSMutableDictionary *localBinaryMetadata;

@property (nonatomic, weak, readwrite) Simperium *simperium;

-(void)loadPendingBinaryDownloads;
-(void)loadPendingBinaryUploads;
-(void)loadLocalBinaryMetadata;
-(void)savePendingBinaryDownloads;
-(void)savePendingBinaryUploads;
-(void)saveLocalBinaryMetadata;


-(BOOL)shouldDownload:(NSURL *)remoteURL binaryInfo:(NSDictionary *)binaryInfo;
-(BOOL)shouldUpload:(NSURL *)remoteURL binaryData:(NSData *)binaryData;

-(NSURL *)remoteUrlForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey;
-(ASIHTTPRequest *)requestWithURL:(NSURL *)url;
-(void)cancelRequestsWithURL:(NSURL *)url;

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
        self.localBinaryMetadata = [NSMutableDictionary dictionary];
		
        [self loadPendingBinaryDownloads];
        [self loadPendingBinaryUploads];
		[self loadLocalBinaryMetadata];
    }
    
    return self;
}


#pragma mark ====================================================================================
#pragma mark Persistance Helpers
#pragma mark ====================================================================================

#warning TODO: Performance performance performance!!!
#warning TODO: Resume on app relaunch
#warning TODO: Ensure local metadata is in sync with CD. Handle logouts
#warning TODO: Add retry mechanisms
#warning TODO: Hook 'uploadIfNeeded' to CoreData. Problem: how to detect if a binary field was just locally updated.
#warning TODO: Nuke 'dataKeyForInfoKey'
#warning TODO: shouldUpload >> CHECK MD5!!!

-(void)loadPendingBinaryDownloads
{
	NSString *rawPendings = [[NSUserDefaults standardUserDefaults] objectForKey:SPPendingBinaryDownloads];
    NSDictionary *pendingDict = [rawPendings objectFromJSONString];
    if (pendingDict.count) {
        [self.pendingBinaryDownloads setValuesForKeysWithDictionary:pendingDict];
	}
}

-(void)loadPendingBinaryUploads
{
	NSString *rawPendings = [[NSUserDefaults standardUserDefaults] objectForKey:SPPendingBinaryUploads];
    NSDictionary *pendingDict = [rawPendings objectFromJSONString];
    if (pendingDict.count) {
        [self.pendingBinaryUploads setValuesForKeysWithDictionary:pendingDict];
	}
}

-(void)loadLocalBinaryMetadata
{
	NSString *rawMetadata = [[NSUserDefaults standardUserDefaults] objectForKey:SPLocalBinaryMetadataKey];
	NSDictionary *localMetadata = [rawMetadata objectFromJSONString];
    if (localMetadata.count) {
        [self.localBinaryMetadata setValuesForKeysWithDictionary:localMetadata];
	}
}

-(void)saveLocalBinaryMetadata
{
    NSString *json = [self.localBinaryMetadata JSONString];
	[[NSUserDefaults standardUserDefaults] setObject:json forKey:SPLocalBinaryMetadataKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
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

-(void)downloadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey binaryInfo:(NSDictionary *)binaryInfo
{
	NSURL *url = [self remoteUrlForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];

	// We're not already in sync, right?
	if([self shouldDownload:url binaryInfo:binaryInfo] == NO)
	{
		return;
	}

	// Wrap up parameters
	NSString *dataKey = [infoKey stringByReplacingOccurrencesOfString:@"Info" withString:@"Data"];
	NSDictionary *callbackDict = @{
									SPBinaryManagerBucketNameKey		: bucketName,
									SPBinaryManagerSimperiumKey			: simperiumKey,
									SPBinaryManagerAttributeDataKey		: dataKey,
									SPBinaryManagerLengthKey			: binaryInfo[SPContentLengthKey]
								};
	
	// Prepare the request itself
	__weak ASIHTTPRequest *request = [self requestWithURL:url];
	
	request.startedBlock = ^{
		if( [self.delegate respondsToSelector:@selector(binaryDownloadStarted:)] ) {
			[self.delegate binaryDownloadStarted:callbackDict];
		}
	};
	
	request.downloadSizeIncrementedBlock = ^(long long size) {
		if( [self.delegate respondsToSelector:@selector(binaryDownloadProgress:percent:)] ) {
			[self.delegate binaryDownloadProgress:callbackDict increment:size];
		}
	};
	
	request.completionBlock = ^{
		// The object wasn't deleted, right?
		SPManagedObject *object = [[self.simperium bucketForName:bucketName] objectForKey:simperiumKey];
		if(!object) {
			return;
		}
		
		// Update the local binary
		[object setValue:request.responseData forKey:dataKey];
		[self.simperium save];
		
		// Update the local metadata. Remote metadata is already up to date!
		[self.localBinaryMetadata setValue:binaryInfo forKey:url.absoluteString];
		[self saveLocalBinaryMetadata];
		
		// Notify the delegate (!)
		DDLogWarn(@"Simperium successfully downloaded binary at URL: %@", url);
		
		if( [self.delegate respondsToSelector:@selector(binaryDownloadSuccessful:)] ) {
			[self.delegate binaryDownloadSuccessful:callbackDict];
		}
	};
	
	request.failedBlock = ^{
		DDLogWarn(@"Simperium error [%@] while downloading binary at URL: %@", request.error, url);
		
		if( [self.delegate respondsToSelector:@selector(binaryDownloadFailed:error:)] ) {
			[self.delegate binaryDownloadFailed:callbackDict error:request.error];
		}
	};
	
	// Cancel previous requests
	[self cancelRequestsWithURL:url];
	
	// Go go go go go!
	DDLogWarn(@"Simperium downloading binary at URL: %@", url);
	[request startAsynchronous];
}

-(void)uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey binaryData:(NSData *)binaryData
{
	NSURL *url = [self remoteUrlForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];
	
	// We're not already in sync, right?
	if([self shouldUpload:url binaryData:binaryData] == NO)
	{
		return;
	}
	
	// Wrap up parameters
	NSString *dataKey = [infoKey stringByReplacingOccurrencesOfString:@"Info" withString:@"Data"];
	NSDictionary *callbackDict = @{
									SPBinaryManagerBucketNameKey		: bucketName,
									SPBinaryManagerSimperiumKey			: simperiumKey,
									SPBinaryManagerAttributeDataKey		: dataKey,
									SPBinaryManagerLengthKey			: @(binaryData.length)
								 };

	// Prepare the request
	__weak ASIHTTPRequest *request = [self requestWithURL:url];
	
	request.startedBlock = ^{
		DDLogWarn(@"Simperium starting binary upload to URL: %@", url);
		
		if( [self.delegate respondsToSelector:@selector(binaryUploadStarted:)] ) {
			[self.delegate binaryUploadStarted:callbackDict];
		}
	};
	
	request.uploadSizeIncrementedBlock = ^(long long size) {
		if( [self.delegate respondsToSelector:@selector(binaryUploadProgress:percent:)] ) {
			[self.delegate binaryUploadProgress:callbackDict increment:size];
		}
	};
	
	request.completionBlock = ^{
		// Update the local metadata
#warning  TODO: Wire this!
		//		[self.localBinaryMetadata setValue:binaryInfo forKey:sourceURL.absoluteString];
		//		[self saveLocalBinaryMetadata];
		
		DDLogWarn(@"Simperium successfully uploaded binary to URL: %@", url);
		
		if( [self.delegate respondsToSelector:@selector(binaryDownloadSuccessful:)] ) {
			[self.delegate binaryDownloadSuccessful:callbackDict];
		}
	};
	
	request.failedBlock = ^{
		DDLogWarn(@"Simperium error [%@] while uploading binary to URL: %@", request.error, url);
		
		if( [self.delegate respondsToSelector:@selector(binaryUploadFailed:error:)] ) {
			[self.delegate binaryUploadFailed:callbackDict error:request.error];
		}
	};
	
	[request appendPostData:binaryData];
	
	// Cancel previous requests!
	[self cancelRequestsWithURL:url];
	
	// Go go go go go!
	DDLogWarn(@"Simperium uploading binary to URL: %@", url);
	[request startAsynchronous];
}


#pragma mark ====================================================================================
#pragma mark Private Download/Upload helpers
#pragma mark ====================================================================================

-(BOOL)shouldDownload:(NSURL *)remoteURL binaryInfo:(NSDictionary *)binaryInfo
{
	NSDictionary *localInfo = self.localBinaryMetadata[remoteURL.absoluteString];
	return ([localInfo[SPContentLengthKey] isEqual:binaryInfo[SPContentLengthKey]] == NO ||
			[localInfo[SPContentHashKey] isEqual:binaryInfo[SPContentHashKey]] == NO);
}

-(BOOL)shouldUpload:(NSURL *)remoteURL binaryData:(NSData *)binaryData
{
	NSDictionary *localInfo = self.localBinaryMetadata[remoteURL.absoluteString];
	return ([localInfo[SPContentLengthKey] unsignedIntegerValue] != binaryData.length);
}


#pragma mark ====================================================================================
#pragma mark Private Requests Helpers
#pragma mark ====================================================================================

-(NSURL *)remoteUrlForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey
{
	// NOTE: downloadURL should hit the attribute with 'Info' ending!
	//		[Base URL] / [App ID] / [Bucket Name] / i / [Simperium Key] / b / [attributeName]Info
	
	NSString *url = [SPBaseURL stringByAppendingFormat:@"%@/%@/i/%@/b/%@", self.simperium.appID, bucketName.lowercaseString, simperiumKey, infoKey];
	return [NSURL URLWithString:url];
}

-(ASIHTTPRequest *)requestWithURL:(NSURL *)url
{
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	request.requestHeaders = [@{ SPSimperiumTokenKey : self.simperium.user.authToken } mutableCopy];
	
#if TARGET_OS_IPHONE
    request.shouldContinueWhenAppEntersBackground = YES;
#endif
	
	return request;
}

-(void)cancelRequestsWithURL:(NSURL *)url
{
	for (ASIHTTPRequest *request in [[ASIHTTPRequest sharedQueue] operations]){
		if([request.url isEqual:url]) {
			[request clearDelegatesAndCancel];
		}
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
