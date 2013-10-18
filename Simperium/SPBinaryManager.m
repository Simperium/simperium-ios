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
#import "ASIHTTPRequest.h"
#import "NSFileManager+Simperium.h"
#import "NSString+Simperium.h"


#warning TODO: Resume on app relaunch
#warning TODO: Handle logouts
#warning TODO: Add retry mechanisms
#warning TODO: Nuke 'dataKeyForInfoKey'
#warning TODO: What happens if upload finishes, the field gets sync'ed (and download begins), and then the localMetadata gets synced?
#warning FIX FIX FIX: binaryInfo, after an upload, comes as a diff!


#pragma mark ====================================================================================
#pragma mark Notifications
#pragma mark ====================================================================================

NSString* const SPBinaryManagerBucketNameKey		= @"SPBinaryManagerBucketNameKey";
NSString* const SPBinaryManagerSimperiumKey			= @"SPBinaryManagerSimperiumKey";
NSString* const SPBinaryManagerAttributeDataKey		= @"SPBinaryManagerAttributeDataKey";
NSString* const SPBinaryManagerLengthKey			= @"SPBinaryManagerLengthKey";


#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString* const SPMetadataFilename			= @"BinaryMetadata.plist";
static NSString* const SPMetadataLengthKey			= @"content-length";
static NSString* const SPMetadataHashKey			= @"hash";

static NSString* const SPBinaryManagerTokenKey		= @"X-Simperium-Token";
static NSInteger const SPBinaryManagerSuccessCode	= 200;

static int ddLogLevel = LOG_LEVEL_INFO;


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPBinaryManager()
@property (nonatomic, strong, readwrite) NSMutableDictionary *localBinaryMetadata;
@property (nonatomic, weak,   readwrite) Simperium *simperium;

-(NSString *)binaryDirectoryPath;
-(NSString *)binaryMetadataPath;

-(void)loadLocalBinaryMetadata;
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
		[self loadLocalBinaryMetadata];
    }
    
    return self;
}


#pragma mark ====================================================================================
#pragma mark Persistance Helpers
#pragma mark ====================================================================================

-(NSString *)binaryDirectoryPath
{
	static NSString *downloadsPath = nil;
	static dispatch_once_t _once;
	
    dispatch_once(&_once, ^{
								NSFileManager *fm = [NSFileManager defaultManager];
								NSString *folder = NSStringFromClass([self class]);
								downloadsPath = [[NSFileManager userDocumentDirectory] stringByAppendingPathComponent:folder];
								if (![fm fileExistsAtPath:downloadsPath]) {
									[fm createDirectoryAtPath:downloadsPath withIntermediateDirectories:YES attributes:nil error:nil];
								}
							});
	
	return downloadsPath;
}

-(NSString *)binaryMetadataPath
{
	return [self.binaryDirectoryPath stringByAppendingPathComponent:SPMetadataFilename];
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

-(void)downloadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey binaryInfo:(NSDictionary *)binaryInfo
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

	// Wrap up parameters
	NSString *dataKey = [infoKey stringByReplacingOccurrencesOfString:@"Info" withString:@"Data"];
	NSDictionary *callbackDict = @{
									SPBinaryManagerBucketNameKey		: bucketName,
									SPBinaryManagerSimperiumKey			: simperiumKey,
									SPBinaryManagerAttributeDataKey		: dataKey,
									SPBinaryManagerLengthKey			: binaryInfo[SPMetadataLengthKey]
								 };
	
	// Prepare the request
	__weak ASIHTTPRequest *request = [self requestWithURL:url];
	
	request.startedBlock = ^{
		if( [self.delegate respondsToSelector:@selector(binaryDownloadStarted:)] ) {
			[self.delegate binaryDownloadStarted:callbackDict];
		}
	};
	
	request.downloadSizeIncrementedBlock = ^(long long size) {
		if( [self.delegate respondsToSelector:@selector(binaryDownloadProgress:increment:)] ) {
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


#pragma mark ====================================================================================
#pragma mark Protected Methods: Upload
#pragma mark ====================================================================================

-(void)uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey binaryData:(NSData *)binaryData
{
	// Is Simperium authenticated?
	if(self.simperium.user.authenticated == NO) {
		return;
	}
	
	// We're not already in sync, right?
	NSURL *url = [self remoteUrlForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];
	if([self shouldUpload:url binaryData:binaryData] == NO) {
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
	
	request.requestMethod = @"PUT";
	request.validatesSecureCertificate = NO;

	request.startedBlock = ^{
		DDLogWarn(@"Simperium starting binary upload to URL: %@", url);
		
		if( [self.delegate respondsToSelector:@selector(binaryUploadStarted:)] ) {
			[self.delegate binaryUploadStarted:callbackDict];
		}
	};
	
	request.uploadSizeIncrementedBlock = ^(long long size) {
		if( [self.delegate respondsToSelector:@selector(binaryUploadProgress:increment:)] ) {
			[self.delegate binaryUploadProgress:callbackDict increment:size];
		}
	};
	
	request.completionBlock = ^{
		if(request.responseStatusCode != SPBinaryManagerSuccessCode) {
			DDLogError(@"Simperium encountered error %d while trying to upload binary: %@",
					   request.responseStatusCode, request.responseStatusMessage);
			return;
		}
		
		// Update the local metadata
		NSDictionary *binaryInfo = [request.responseString objectFromJSONString];
		[self.localBinaryMetadata setValue:binaryInfo forKey:url.absoluteString];
		[self saveLocalBinaryMetadata];
		
		// Hit the delegate
		DDLogWarn(@"Simperium successfully uploaded binary to URL: %@. Response: %@", url, binaryInfo);
		
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
	return (localInfo == nil || [localInfo[SPMetadataHashKey] isEqual:binaryInfo[SPMetadataHashKey]] == NO);
}

-(BOOL)shouldUpload:(NSURL *)remoteURL binaryData:(NSData *)binaryData
{
	NSDictionary *localInfo = self.localBinaryMetadata[remoteURL.absoluteString];
	
	// Speed speed: if the length itself is different, don't even check the hash
	if(localInfo == nil || [localInfo[SPMetadataLengthKey] unsignedIntegerValue] != binaryData.length) {
		return YES;
	// Hash..!
	} else {
		NSString *binaryHash = [NSString sp_md5StringFromData:binaryData];
		return ([localInfo[SPMetadataHashKey] isEqualToString:binaryHash] == NO);
	}
}


#pragma mark ====================================================================================
#pragma mark Private Requests Helpers
#pragma mark ====================================================================================

-(NSURL *)remoteUrlForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey
{
	// NOTE: downloadURL should hit the attribute with 'Info' ending!
	//		[Base URL] / [App ID] / [Bucket Name] / i / [Simperium Key] / b / [attributeName]Info
	
	return [NSURL URLWithString:[SPBaseURL stringByAppendingFormat:@"%@/%@/i/%@/b/%@",
								 self.simperium.appID, bucketName.lowercaseString, simperiumKey, infoKey]];
}

-(ASIHTTPRequest *)requestWithURL:(NSURL *)url
{
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	
	request.requestHeaders = [@{
									SPBinaryManagerTokenKey : self.simperium.user.authToken
								} mutableCopy];
	
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
