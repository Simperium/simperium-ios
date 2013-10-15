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
#import "NSFileManager+Simperium.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

NSString* const SPBinaryManagerBucketNameKey = @"SPBinaryManagerBucketNameKey";
NSString* const SPBinaryManagerSimperiumKey = @"SPBinaryManagerSimperiumKey";
NSString* const SPBinaryManagerAttributeDataKey = @"SPBinaryManagerAttributeDataKey";
NSString* const SPBinaryManagerLengthKey = @"SPBinaryManagerLengthKey";

static NSString* const SPContentLengthKey = @"content-length";
static NSString* const SPContentHashKey = @"hash";
static NSString* const SPSimperiumTokenKey = @"X-Simperium-Token";

static int ddLogLevel = LOG_LEVEL_INFO;


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPBinaryManager()
@property (nonatomic, strong, readwrite) NSMutableDictionary *localBinaryMetadata;
@property (nonatomic, weak,   readwrite) Simperium *simperium;

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
        self.localBinaryMetadata = [NSMutableDictionary dictionary];
		[self loadLocalBinaryMetadata];
		
//		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 5.0f * NSEC_PER_SEC);
//		dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
//		{
//			NSData* data = [self randomDataWithBytes:1025];
//			[self uploadIfNeeded:@"SDTask" simperiumKey:@"a229499265eb4e878f454b86d1a2632c" infoKey:@"binaryInfo" binaryData:data];
//		});
    }
    
    return self;
}

//-(NSData *)randomDataWithBytes: (NSUInteger)length
//{
//    NSMutableData *mutableData = [NSMutableData dataWithCapacity: length];
//    for (unsigned int i = 0; i < length; i++) {
//        NSInteger randomBits = arc4random();
//        [mutableData appendBytes: (void *) &randomBits length: 1];
//    }
//	
//	return mutableData;
//}


#pragma mark ====================================================================================
#pragma mark Persistance Helpers
#pragma mark ====================================================================================

#warning TODO: Resume on app relaunch
#warning TODO: Add retry mechanisms
#warning TODO: Ensure local metadata is in sync with CD. Handle logouts
#warning TODO: Hook 'uploadIfNeeded' to CoreData. Problem: how to detect if a binary field was just locally updated.
#warning TODO: Nuke 'dataKeyForInfoKey'
#warning TODO: shouldUpload >> CHECK MD5!!!

-(NSString *)binaryDirectoryPath
{
	static NSString *downloadsPath = nil;
	static dispatch_once_t _once;
	
	NSString* const SPBinaryDirectoryName = @"SPBinary";
	
    dispatch_once(&_once, ^{
					  NSFileManager *fm = [NSFileManager defaultManager];
					  downloadsPath = [[NSFileManager userDocumentDirectory] stringByAppendingPathComponent:SPBinaryDirectoryName];
					  if (![fm fileExistsAtPath:downloadsPath])
					  {
						  [fm createDirectoryAtPath:downloadsPath withIntermediateDirectories:YES attributes:nil error:nil];
					  }
                  });
	
	return downloadsPath;
}

-(NSString *)binaryMetadataPath
{
	NSString* const SPBinaryMetadataFilename = @"BinaryMetadata.plist";
	return [self.binaryDirectoryPath stringByAppendingPathComponent:SPBinaryMetadataFilename];
}

-(void)loadLocalBinaryMetadata
{
	NSDictionary *localMetadata = [[NSDictionary alloc] initWithContentsOfFile:self.binaryMetadataPath];
	if (localMetadata.count) {
		[self.localBinaryMetadata setValuesForKeysWithDictionary:localMetadata];
	}
}

-(void)saveLocalBinaryMetadata
{
	[self.localBinaryMetadata writeToFile:self.binaryMetadataPath atomically:NO];
}


#pragma mark ====================================================================================
#pragma mark Protected Methods
#pragma mark ====================================================================================

-(void)downloadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey binaryInfo:(NSDictionary *)binaryInfo
{
	// Is Simperium authenticated?
	if(self.simperium.user.authenticated == NO)
	{
		return;
	}
	
	// We're not already in sync, right?
	NSURL *url = [self remoteUrlForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];
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

-(void)uploadIfNeeded:(NSString *)bucketName simperiumKey:(NSString *)simperiumKey infoKey:(NSString *)infoKey binaryData:(NSData *)binaryData
{
	// Is Simperium authenticated?
	if(self.simperium.user.authenticated == NO)
	{
		return;
	}
	
	// We're not already in sync, right?
	NSURL *url = [self remoteUrlForBucket:bucketName simperiumKey:simperiumKey infoKey:infoKey];
	
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
		// Update the local metadata
#warning  TODO: Wire this!
		//		[self.localBinaryMetadata setValue:binaryInfo forKey:sourceURL.absoluteString];
		//		[self saveLocalBinaryMetadata];
		NSLog(@"Response: %@", request.responseString);
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
