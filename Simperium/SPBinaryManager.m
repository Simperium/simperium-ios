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


#warning TODO: SPBinaryManager should have its own GCD queue
#warning TODO: Don't upload if local mtime < remoteMtime
#warning TODO: Resume on app relaunch
#warning TODO: Handle logouts
#warning TODO: Add retry mechanisms
#warning TODO: Handle Nulls


#pragma mark ====================================================================================
#pragma mark Notifications
#pragma mark ====================================================================================

NSString* const SPBinaryManagerBucketNameKey			= @"SPBinaryManagerBucketNameKey";
NSString* const SPBinaryManagerSimperiumKey				= @"SPBinaryManagerSimperiumKey";
NSString* const SPBinaryManagerAttributeDataKey			= @"SPBinaryManagerAttributeDataKey";
NSString* const SPBinaryManagerLengthKey				= @"content-length";
NSString* const SPBinaryManagerHashKey					= @"hash";
NSString* const SPBinaryManagerModificationTimeKey		= @"mtime";


#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString* const SPBinaryManagerMetadataFilename	= @"BinaryMetadata.plist";
static NSString* const SPBinaryManagerTokenKey			= @"X-Simperium-Token";

static int ddLogLevel = LOG_LEVEL_INFO;


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPBinaryManager()
@property (nonatomic, strong, readwrite) SPHttpRequestQueue *httpRequestsQueue;
@property (nonatomic, weak,   readwrite) Simperium *simperium;

@property (nonatomic, strong, readwrite) NSMutableDictionary *localMetadata;
@property (nonatomic, strong, readwrite) NSMutableSet *downloads;
@property (nonatomic, strong, readwrite) NSMutableSet *uploads;

-(NSString *)localMetadataPath;

-(void)loadLocalMetadata;
-(void)saveLocalMetadata;

-(NSURL *)remoteUrlForBucket:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey;
@end


#pragma mark ====================================================================================
#pragma mark SPBinaryManager
#pragma mark ====================================================================================

@implementation SPBinaryManager

-(id)initWithSimperium:(Simperium *)aSimperium
{
    if (self = [super init]) {
		// We'll have our own Http Queue
		self.httpRequestsQueue = [[SPHttpRequestQueue alloc] init];
		
		// Load local metadata
		self.localMetadata = [NSMutableDictionary dictionary];
		[self loadLocalMetadata];
		
		// Transient: Store the hash of the current downloads/uploads
		self.downloads = [NSMutableSet set];
		self.uploads   = [NSMutableSet set];
		
		// We'll need this one!
        self.simperium = aSimperium;
    }
    
    return self;
}


#pragma mark ====================================================================================
#pragma mark Persistance Helpers
#pragma mark ====================================================================================

-(NSString *)localMetadataPath
{
	return [[NSFileManager binaryDirectory] stringByAppendingPathComponent:SPBinaryManagerMetadataFilename];
}

-(void)loadLocalMetadata
{
	NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
	NSDictionary *persisted = [[NSDictionary alloc] initWithContentsOfFile:self.localMetadataPath];
	if (persisted.count) {
		[metadata setValuesForKeysWithDictionary:persisted];
	}
	
	self.localMetadata = metadata;
}

-(void)saveLocalMetadata
{
	[self.localMetadata writeToFile:self.localMetadataPath atomically:NO];
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

	NSURL *url = [self remoteUrlForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];

	// Are we there yet?
	NSDictionary *localMetadata	= self.localMetadata[url.absoluteString];
	NSString *localHash			= localMetadata[SPBinaryManagerHashKey];
	NSNumber *localMtime		= localMetadata[SPBinaryManagerModificationTimeKey];
	NSString *remoteHash		= binaryInfo[SPBinaryManagerHashKey];
	NSNumber *remoteMtime		= binaryInfo[SPBinaryManagerModificationTimeKey];

	@synchronized(self) {
		if ([localHash isEqual:remoteHash] || [self.downloads containsObject:remoteHash] || [self.uploads containsObject:remoteHash]) {
			return;
		} else if(localMtime.intValue >= remoteMtime.intValue) {
			return;
		} else {
			[self.downloads addObject:remoteHash];
		}
	}
		
	// Prepare the request
	SPHttpRequest *request = [SPHttpRequest requestWithURL:url method:SPHttpRequestMethodsGet];
	
	request.headers = @{
		SPBinaryManagerTokenKey : self.simperium.user.authToken
	};
	
	request.userInfo = @{
		SPBinaryManagerBucketNameKey		: bucketName,
		SPBinaryManagerSimperiumKey			: simperiumKey,
		SPBinaryManagerAttributeDataKey		: dataKey,
		SPBinaryManagerLengthKey			: binaryInfo[SPBinaryManagerLengthKey],
		SPBinaryManagerHashKey				: binaryInfo[SPBinaryManagerHashKey],
		SPBinaryManagerModificationTimeKey	: binaryInfo[SPBinaryManagerModificationTimeKey]
	};
	
	request.delegate = self;
	request.selectorStarted = @selector(downloadStarted:);
	request.selectorProgress = @selector(downloadProgress:);
	request.selectorSuccess = @selector(downloadSuccess:);
	request.selectorFailed = @selector(downloadFailed:);
	
	// Cancel previous requests with the same URL
	[self.httpRequestsQueue cancelRequestsWithURL:url];
	
	// Go!
	[self.httpRequestsQueue enqueueHttpRequest:request];
}


#pragma mark ====================================================================================
#pragma mark Private Methods: SPHttpRequest DOWNLOAD delegates
#pragma mark ====================================================================================

-(void)downloadStarted:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium downloading binary at URL: %@", request.url);
	
	if( [self.delegate respondsToSelector:@selector(binaryDownloadStarted:)] ) {
		[self.delegate binaryDownloadStarted:request.userInfo];
	}
}

-(void)downloadProgress:(SPHttpRequest *)request
{
	float progress = [request.userInfo[SPBinaryManagerLengthKey] floatValue] / (request.responseData.length * 1.0f);
	DDLogWarn(@"Simperium downloaded [%f%%] of [%@]", progress, request.url);
	
	if( [self.delegate respondsToSelector:@selector(binaryDownloadProgress:progress:)] ) {
		[self.delegate binaryDownloadProgress:request.userInfo progress:progress];
	}
}

-(void)downloadFailed:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium error [%@] while downloading binary at URL: %@", request.error, request.url);
	
	[self.downloads removeObject:request.userInfo[SPBinaryManagerHashKey]];
	
	if( [self.delegate respondsToSelector:@selector(binaryDownloadFailed:error:)] ) {
		[self.delegate binaryDownloadFailed:request.userInfo error:request.error];
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
	NSString *hash			= userInfo[SPBinaryManagerHashKey];
	NSNumber *mtime			= userInfo[SPBinaryManagerModificationTimeKey];
	
	// The object wasn't deleted, right?
	SPManagedObject *object = [[self.simperium bucketForName:bucketName] objectForKey:simperiumKey];
	if(!object) {
		return;
	}
	
	// Update the local binary
	[object setValue:request.responseData forKey:dataKey];
	[self.simperium save];
	
	// Update the local metadata. Remote metadata is already up to date!
	NSDictionary *metadata = @{
		SPBinaryManagerHashKey				: hash,
		SPBinaryManagerModificationTimeKey	: mtime
	};
	
	[self.localMetadata setValue:metadata forKey:request.url.absoluteString];
	[self saveLocalMetadata];
	
	// Remove the hash from the current downloads collection
	[self.downloads removeObject:hash];
	
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
	// Is Simperium authenticated?
	if(self.simperium.user.authenticated == NO) {
		return;
	}

	// We're not already in sync, right?
	NSURL *url = [self remoteUrlForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];
	
	// Are we there yet?
	NSString *localHash  = [NSString sp_md5StringFromData:binaryData];
	NSString *remoteHash = self.localMetadata[url.absoluteString][SPBinaryManagerHashKey];
	
	@synchronized(self) {
		if ([localHash isEqualToString:remoteHash] || [self.uploads containsObject:localHash]) {
			return;
		} else {
			[self.uploads addObject:localHash];
		}
	}
	
	// Prepare the request
	SPHttpRequest *request = [SPHttpRequest requestWithURL:url method:SPHttpRequestMethodsPut];
	
	request.headers = @{
		SPBinaryManagerTokenKey : self.simperium.user.authToken
	};
	
	request.userInfo = @{
		SPBinaryManagerBucketNameKey	: bucketName,
		SPBinaryManagerSimperiumKey		: simperiumKey,
		SPBinaryManagerAttributeDataKey	: dataKey,
		SPBinaryManagerLengthKey		: @(binaryData.length),
		SPBinaryManagerHashKey			: localHash
	};
	
	request.postData = binaryData;
	
	request.delegate = self;
	request.selectorStarted = @selector(uploadStarted:);
	request.selectorProgress = @selector(uploadProgress:);
	request.selectorSuccess = @selector(uploadSuccess:);
	request.selectorFailed = @selector(uploadFailed:);
	
	// Cancel previous requests with the same URL
	[self.httpRequestsQueue cancelRequestsWithURL:url];
	
	// Go!
	[self.httpRequestsQueue enqueueHttpRequest:request];
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
	DDLogWarn(@"Simperium uploaded [%f.1%%] of [%@]", request.uploadProgress, request.url);
	
	if( [self.delegate respondsToSelector:@selector(binaryUploadProgress:progress:)] ) {
		[self.delegate binaryUploadProgress:request.userInfo progress:request.uploadProgress];
	}
}

-(void)uploadFailed:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium error [%@] while uploading binary to URL: %@", request.error, request.url);

	NSString *hash = request.userInfo[SPBinaryManagerHashKey];
	[self.uploads removeObject:hash];
	
	if( [self.delegate respondsToSelector:@selector(binaryUploadFailed:error:)] ) {
		[self.delegate binaryUploadFailed:request.userInfo error:request.error];
	}
}

-(void)uploadSuccess:(SPHttpRequest *)request
{
	DDLogWarn(@"Simperium successfully uploaded binary to URL: %@", request.url);
		
	// Update the local metadata
	NSDictionary *metadata = [request.responseString objectFromJSONString];
	[self.localMetadata setValue:metadata forKey:request.url.absoluteString];
	[self saveLocalMetadata];
	
	// Cleanup
	NSString *hash = request.userInfo[SPBinaryManagerHashKey];
	[self.uploads removeObject:hash];
	
	// Notify the delegate (!)
	if( [self.delegate respondsToSelector:@selector(binaryUploadSuccessful:)] ) {
		[self.delegate binaryUploadSuccessful:request.userInfo];
	}
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
