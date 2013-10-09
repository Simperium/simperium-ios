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



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString* const SPPendingBinaryDownloads = @"SPPendingBinaryDownloads";
static NSString* const SPPendingBinaryUploads = @"SPPendingBinaryUploads";


#pragma mark ====================================================================================
#pragma mark Private Properties
#pragma mark ====================================================================================

@interface SPBinaryManager()
@property (nonatomic, strong, readwrite) NSMutableDictionary *pendingBinaryDownloads;
@property (nonatomic, strong, readwrite) NSMutableDictionary *pendingBinaryUploads;
@property (nonatomic, strong, readwrite) NSMutableDictionary *transmissionProgress;

@property (nonatomic, strong, readwrite) NSMutableSet *delegates;

@property (nonatomic, strong, readwrite) Simperium *simperium;

-(void)loadPendingBinaryDownloads;
-(void)loadPendingBinaryUploads;
-(void)savePendingBinaryDownloads;
-(void)savePendingBinaryUploads;
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
        self.delegates = [NSMutableSet set];
		
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
#pragma mark Delegate Helpers
#pragma mark ====================================================================================

-(void)addDelegate:(id)delegate
{
	NSValue *wrappedDelegate = [NSValue valueWithNonretainedObject:delegate];
    [self.delegates addObject:wrappedDelegate];
}

-(void)removeDelegate:(id)delegate
{
	NSValue *wrappedDelegate = [NSValue valueWithNonretainedObject:delegate];
    [self.delegates removeObject:wrappedDelegate];
}


#pragma mark ====================================================================================
#pragma mark Public Methods
#pragma mark ====================================================================================

-(void)startDownloadIfNeeded:(NSString *)simperiumKey bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName
{
#warning TODO Fill Me!
}


#warning TODO Hook Up Uploads!

//-(void)addBinary:(NSData *)binaryData toObject:(SPManagedObject *)object bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName
//{
//    // Make sure the object has a simperiumKey (it might not if it was just created)
//    if (!object.simperiumKey) {
//        object.simperiumKey = [NSString sp_makeUUID];
//	}
//	
//    [self.binaryManager addBinary:binaryData toObject:object bucketName:bucketName attributeName:attributeName];
//}



#pragma mark ====================================================================================
#pragma mark LEGACY!
#pragma mark ====================================================================================

#warning TODO Nuke once ready!

//-(void)addPendingReferenceToFile:(NSString *)filename fromKey:(NSString *)fromKey bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName
//{
//    NSMutableDictionary *binaryPath = [NSMutableDictionary dictionaryWithObjectsAndKeys:
//                                 fromKey, SPPathKey,
//                                 bucketName, SPPathBucket,
//                                 attributeName, SPPathAttribute, nil];
//
//    NSLog(@"Simperium adding pending file reference for %@.%@=%@", fromKey, attributeName, filename);
//    
//    // Check to see if any references are already being tracked for this entity
//    NSMutableArray *paths = [self.pendingBinaryDownloads objectForKey: filename];
//    if (paths == nil) {
//        paths = [NSMutableArray arrayWithCapacity:3];
//        [self.pendingBinaryDownloads setObject: paths forKey: filename];
//    }
//    
//    [paths addObject:binaryPath];
//    [self startDownloading:filename];
//    [self savePendingBinaryDownloads];
//}
//
//-(void)resolvePendingReferencesToFile:(NSString *)filename
//{
//    // The passed entity is now synced, so check for any pending references to it that can now be resolved
//    NSMutableArray *paths = [self.pendingBinaryDownloads objectForKey: filename];
//    if (paths != nil) {
//        for (NSDictionary *path in paths) {
//            NSString *fromKey = [path objectForKey:SPPathKey];
//            NSString *fromBucketName = [path objectForKey:SPPathBucket];
//            NSString *attributeName = [path objectForKey:SPPathAttribute];
//
//            NSLog(@"Simperium resolving pending file reference for %@.%@=%@", fromKey, attributeName, filename);
//            //for (id<SimperiumDelegate>delegate in delegates) {
//                //                if ([delegate respondsToSelector:@selector(fileLoaded:forEntity:memberName:)]) {
//                //                    [delegate fileLoaded:filename forEntity:binaryPath.entity memberName:binaryPath.memberName];
//                //                }
//            //}
//            SPBucket *bucket = [self.simperium bucketForName:fromBucketName];
//            SPManagedObject *object = [bucket objectForKey:fromKey];
//            [object setValue:filename forKey: attributeName];
//            [object.ghost.memberData setObject:filename forKey: attributeName];
//            object.ghost.needsSave = YES;
//            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [self.simperium saveWithoutSyncing];
//                NSSet *changedKeys = [NSSet setWithObject:fromKey];
//                NSDictionary *userInfoAdded = [NSDictionary dictionaryWithObjectsAndKeys:
//                                               fromBucketName, @"bucketName",
//                                               changedKeys, @"keys", nil];
//                [[NSNotificationCenter defaultCenter] postNotificationName:@"ProcessorDidChangeObjectsNotification" object:self userInfo:userInfoAdded];
//            });
//        }
//        
//        // All references to entity were resolved above, so remove it from the pending array
//        [self.pendingBinaryDownloads removeObjectForKey:filename];
//    }
//    [self savePendingBinaryDownloads];
//}
//
//-(void)addBinary:(NSData *)binaryData toObject:(SPManagedObject *)object bucketName:(NSString *)bucketName attributeName:(NSString *)attributeName
//{
//    // Remember all the details so the filename can be set AFTER it has finished uploading
//    // (otherwise other clients will try to download it before it's ready)
//    //SPObjectPath *path = [[SPObjectPath alloc] initWithKey:object.simperiumKey className:bucketName attributeName:attributeName];
//    NSMutableDictionary *path = [NSMutableDictionary dictionaryWithObjectsAndKeys:
//                                       object.simperiumKey, SPPathKey,
//                                       bucketName, SPPathBucket,
//                                       attributeName, SPPathAttribute, nil];
//
//    [self.pendingBinaryUploads setObject:path forKey:nil]; //[self prefixFilename: filename]];
//    [self savePendingBinaryUploads];
//    
////    [self startUploading:filename];
//}
//
//-(void)finishedDownloading:(NSString *)filename
//{
//    [self resolvePendingReferencesToFile:filename];
//    [self.transmissionProgress setObject:[NSNumber numberWithInt:0] forKey:filename];
//    for (id<SPBinaryTransportDelegate>delegate in self.delegates) {
//        if ([delegate respondsToSelector:@selector(binaryDownloadSuccessful:)]) 
//            [delegate binaryDownloadSuccessful:filename];
//    }
//}
//
//-(void)finishedUploading:(NSString *)filename
//{
//    // Safe now to set the filename parameter and sync it to other clients
//    NSDictionary *path = [self.pendingBinaryUploads objectForKey:filename];
//    NSString *fromKey = [path objectForKey:SPPathKey];
//    NSString *fromBucketName = [path objectForKey:SPPathBucket];
//    NSString *attributeName = [path objectForKey:SPPathAttribute];
//    
//    SPBucket *bucket = [self.simperium bucketForName:fromBucketName];
//    NSManagedObject *object = [bucket objectForKey:fromKey];
//    [object setValue:filename forKey:attributeName];
//    [self.simperium save];
//    [self.pendingBinaryUploads removeObjectForKey:filename];
//    [self savePendingBinaryUploads];
//    
//    //[self resolvePendingReferencesToFile:filename];
//    [self.transmissionProgress setObject:[NSNumber numberWithInt:0] forKey:filename];
//    for (id<SPBinaryTransportDelegate>delegate in self.delegates) {
//        if ([delegate respondsToSelector:@selector(binaryUploadSuccessful:)]) 
//            [delegate binaryUploadSuccessful:filename];
//    }
//}














//-(id)initWithSimperium:(Simperium *)aSimperium
//{
//    NSLog(@"Simperium initializing binary manager");
//    if ((self = [super initWithSimperium:aSimperium])) {
//        downloadsInProgressData = [NSMutableDictionary dictionaryWithCapacity: 3];
//        downloadsInProgressRequests = [NSMutableDictionary dictionaryWithCapacity: 3];
//        uploadsInProgressRequests = [NSMutableDictionary dictionaryWithCapacity: 3];
//        remoteFilesizeCache = [NSMutableDictionary dictionaryWithCapacity: 3];
//        bgTasks = [NSMutableDictionary dictionaryWithCapacity: 3];
//        
//        backgroundQueue = dispatch_queue_create("com.simperium.simperium.backgroundQueue", NULL);
//    }
//    return self;
//}
//
//-(NSString *)addBinary:(NSData *)binaryData toObject:(SPManagedObject *)object bucketName:(NSString *)name attributeName:(NSString *)attributeName
//{
//    return [super addBinary:binaryData toObject:object bucketName:name attributeName:attributeName];
//}
//
//-(void)startDownloading:(NSString *)filename
//{
//    [self checkOrGetBinaryAuthentication];
//    [self connectToAWS];
//    
//    hackFilename = [filename copy];
//    
//    UIApplication *app = [UIApplication sharedApplication];
//    UIBackgroundTaskIdentifier tempBgTask = [app beginBackgroundTaskWithExpirationHandler:^{
//        
//        NSLog(@"Expired Download for %@.",filename);
//        [app endBackgroundTask:[[self.bgTasks objectForKey:filename] intValue]];
//        [self.bgTasks setObject:[NSNumber numberWithInt:UIBackgroundTaskInvalid] forKey:filename];
//        
//    }];
//    
//    [self.bgTasks setObject:[NSNumber numberWithInt: tempBgTask] forKey:filename];
//    dispatch_async(backgroundQueue, ^{
//        __block int sizeOfRemoteFile;
//        // Get the file size on another thread since it can take awhile
//        // (not strictly safe to do this here due to the cache implementation, but ok for prototype)
//        sizeOfRemoteFile = [self sizeOfRemoteFile:filename];
//        
//        dispatch_async(dispatch_get_main_queue(), ^{
//            NSLog(@"Start Downloading: %@/%@",[self getS3BucketName],filename);
//            NSLog(@"Size of remote file: %d",sizeOfRemoteFile);
//            
//            // @TODO error handling ?
//            [transmissionProgress setObject:[NSNumber numberWithInt:sizeOfRemoteFile] forKey:filename];
//            
//            S3GetObjectRequest *downloadRequest = [[S3GetObjectRequest alloc] initWithKey:filename withBucket: [self getS3BucketName]];
//            
//            [downloadRequest setDelegate:self];
//            downloadResponse = [self.awsConnection getObject: downloadRequest];
//            NSMutableData *fileData = [[NSMutableData alloc] initWithCapacity:1024];
//            [downloadsInProgressData setObject: fileData forKey:filename];
//            [downloadsInProgressRequests setObject: downloadRequest forKey:filename];
//            
//            for (id<SPBinaryTransportDelegate>delegate in delegates) {
//                if ([delegate respondsToSelector:@selector(binaryDownloadStarted:)])
//                    [delegate binaryDownloadStarted:filename];
//            }
//        });
//		
//    });
//}
//
//-(void)startUploading:(NSString *)filename
//{
//    [self checkOrGetBinaryAuthentication];
//    [self connectToAWS];
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
//    //dispatch_async(dispatch_get_main_queue(), ^{
//	NSData *data = [self dataForFilename:filename];
//	if (data == nil) {
//		NSAssert1(0, @"Simperium error: could not find binary file: %@", filename);
//	}
//	
//    @try {
//        NSString *s3bucketName = [self getS3BucketName];
//        NSString *s3filename = [self prefixFilename:filename];
//        S3PutObjectRequest *uploadRequest = [[S3PutObjectRequest alloc] initWithKey:s3filename inBucket:s3bucketName];
//		
//        [uploadRequest setDelegate: self];
//        uploadRequest.data = data;
//		
//        NSLog(@"Simperium uploading binary %@ to path: %@", s3filename, s3bucketName);
//        NSLog(@"Size of local file: %d",[self sizeOfLocalFile:filename]);
//		
//        // @TODO error handling ?
//        [transmissionProgress setObject:[NSNumber numberWithInt: [self sizeOfLocalFile:filename]] forKey:filename];
//		
//        uploadResponse = [self.awsConnection putObject: uploadRequest];
//        [uploadsInProgressRequests setObject: uploadRequest forKey: filename];
//		
//        for (id<SPBinaryTransportDelegate>delegate in delegates) {
//            if ([delegate respondsToSelector:@selector(binaryUploadStarted:)])
//                [delegate binaryUploadStarted:filename];
//        }
//    }   @catch (AmazonClientException *exception) {
//        NSLog(@"S3 error: %@", exception.message);
//    }
//    //});
//}
//
//// Sent as data is received.
//-(void)request: (S3Request *)request didReceiveData: (NSData *) data {
//    
//    // Only use this for download notifications
//    if ([request isKindOfClass:[S3PutObjectRequest class]])
//		return;
//	
//    if (data != nil) {
//		
//        long progress = [[transmissionProgress objectForKey:request.key] intValue];
//        long receivedSize = [data length];
//        [transmissionProgress setObject:[NSNumber numberWithInt:(progress - receivedSize)] forKey:request.key];
//        
//        for (id<SPBinaryTransportDelegate>delegate in delegates) {
//            if ([delegate respondsToSelector: @selector(binaryDownloadReceivedBytes:forFilename:)]) {
//                [delegate binaryDownloadReceivedBytes:[data length] forFilename: request.key];
//            }
//			
//            if ([delegate respondsToSelector: @selector(binaryDownloadPercent:object:)]) {
//                int remoteSize = [self sizeOfRemoteFile:request.key];
//                int remoteRemaining = [self sizeRemainingToTransmit:request.key];
//                float percent = 1.0 - ((float) remoteRemaining / (float) remoteSize);
//                NSDictionary *objectPath = [[pendingBinaryDownloads objectForKey:request.key] objectAtIndex:0];
//                NSString *fromKey = [objectPath objectForKey:SPPathKey];
//                NSString *fromBucketName = [objectPath objectForKey:SPPathBucket];
//                SPManagedObject *object = [[simperium bucketForName:fromBucketName] objectForKey:fromKey];
//                [delegate binaryDownloadPercent:percent object:object];
//            }
//        }
//    }
//    else {
//        
//        for (id<SPBinaryTransportDelegate>delegate in delegates) {
//            if ([delegate respondsToSelector: @selector(binaryDownloadReceivedBytes:forFilename:)]) {
//                [delegate binaryDownloadReceivedBytes:0 forFilename: request.key];
//            }
//        }
//    }
//}
//
//// Sent when body data has been read and processed.
//-(void)request: (S3Request *)request didCompleteWithResponse: (S3Response *) response {
//    // TODO: handle AWS exceptions
//    NSLog(@"Simperium binary request completed (%@)",request.key);
//    
//    UIBackgroundTaskIdentifier bgTask = [[self.bgTasks objectForKey:request.key] intValue];
//    if (bgTask != UIBackgroundTaskInvalid) {
//        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
//        bgTask = UIBackgroundTaskInvalid;
//        [self.bgTasks setObject:[NSNumber numberWithInt: UIBackgroundTaskInvalid] forKey:request.key];
//    }
//    
//    // For download requests
//    if ([downloadsInProgressData objectForKey:request.key] != nil) {
//        NSLog(@"Simperium binary download finished (%d)",response.httpStatusCode);
//        
//        [downloadsInProgressData setObject:response.body forKey:request.key];
//        NSString *path = [self pathForFilename: request.key];
//        NSError *theError;
//        if (![[downloadsInProgressData objectForKey:request.key] writeToFile:path options:NSDataWritingAtomic error: &theError]) {
//            NSLog(@"Simperium error storing downloaded binary file: %@", [theError localizedDescription]);
//            NSLog(@"Failured during writeToFile");
//        }
//        
//        [self finishedDownloading:request.key];
//        [downloadsInProgressData removeObjectForKey:request.key];
//    }
//    else if ([uploadsInProgressRequests objectForKey:request.key] != nil) {
//        NSLog(@"Simperium binary upload finished (%d)",response.httpStatusCode);
//        [uploadsInProgressRequests removeObjectForKey:request.key];
//        [self finishedUploading:request.key];
//    }
//    else {
//        NSLog(@"How did we get in here?");
//    }
//}
//
//// Sent when the request transmitted data.
//-(void)request: (S3Request *)request didSendData: (NSInteger) bytesWritten totalBytesWritten: (NSInteger) totalBytesWritten totalBytesExpectedToWrite: (NSInteger) totalBytesExpectedToWrite {
//    
//    long progress = [[transmissionProgress objectForKey:request.key] intValue];
//    [transmissionProgress setObject:[NSNumber numberWithInt:(progress - bytesWritten)] forKey:request.key];
//    
//    for (id<SPBinaryTransportDelegate>delegate in delegates) {
//        if ([delegate respondsToSelector: @selector(binaryUploadReceivedBytes:forFilename:)]) {
//            [delegate binaryUploadTransmittedBytes:bytesWritten forFilename: request.key];
//        }
//        
//        if ([delegate respondsToSelector: @selector(binaryUploadPercent:object:)]) {
//            
//            int remoteSize = [self sizeOfLocalFile:request.key];
//            int remoteRemaining = [self sizeRemainingToTransmit:request.key];
//            float percent = 1.0 - ((float) remoteRemaining / (float) remoteSize);
//            
//            NSDictionary *objectPath = [pendingBinaryUploads objectForKey:request.key];
//            NSString *fromKey = [objectPath objectForKey:SPPathKey];
//            NSString *fromBucketName = [objectPath objectForKey:SPPathBucket];
//            
//            SPManagedObject *object = [[simperium bucketForName:fromBucketName] objectForKey:fromKey];
//            [delegate binaryUploadPercent:percent object: object];
//        }
//    }
//}
//


@end
