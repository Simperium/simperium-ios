//
//  SPChangeProcessorTests.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 6/10/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Simperium.h"
#import "MockSimperium.h"
#import "SPBucket+Internals.h"
#import "SPGhost.h"
#import "SPChangeProcessor.h"
#import "SPCoreDataStorage.h"
#import "Post.h"

#import "NSString+Simperium.h"
#import "JSONKit+Simperium.h"

#import "DiffMatchPatch.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSInteger const SPNumberOfEntities       = 1000;
static NSString * const SPRemoteClientID        = @"OSX-Remote!";
static NSUInteger const SPRandomStringLength    = 100;


#pragma mark ====================================================================================
#pragma mark SPChangeProcessorTests
#pragma mark ====================================================================================

@interface SPChangeProcessorTests : XCTestCase

@end

@implementation SPChangeProcessorTests

- (void)testApplyRemoteDiffWithUncommitedChanges
{
	MockSimperium* s				= [MockSimperium mockSimperium];
	SPBucket* bucket                = [s bucketForName:NSStringFromClass([Post class])];
	SPCoreDataStorage* storage		= bucket.storage;
	NSMutableArray* posts           = [NSMutableArray array];
	NSString *titleMemberName       = NSStringFromSelector(@selector(title));
    
    // ===================================================================================================
	// Insert Posts
    // ===================================================================================================
    //
	for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
		Post* post = [storage insertNewObjectForBucketName:bucket.name simperiumKey:nil];
		post.title = [NSString sp_randomStringOfLength:SPRandomStringLength];
        
        // Intialize SPGhost: we're not relying on the backend to confirm these additions!
        NSMutableDictionary *memberData = [post.dictionary mutableCopy];
        SPGhost *ghost                  = [[SPGhost alloc] initWithKey:post.simperiumKey memberData:memberData];
        ghost.version                   = @"1";
        post.ghost                      = ghost;
        post.ghostData                  = [memberData sp_JSONString];
		[storage save];
        
		[posts addObject:post];
	}

    // ===================================================================================================
    // Prepare Remote Changes
    // ===================================================================================================
    //
    DiffMatchPatch *dmp             = [[DiffMatchPatch alloc] init];
    NSMutableDictionary *changes    = [NSMutableDictionary dictionary];
    NSMutableDictionary *newTitles  = [NSMutableDictionary dictionary];
    
    for (Post *post in posts) {
        NSString *changeVersion     = [NSString sp_makeUUID];
        NSString *startVersion      = post.ghost.version;
        NSString *endVersion        = [NSString stringWithFormat:@"%d", startVersion.intValue + 1];
        NSString *newTitle          = [NSString sp_randomStringOfLength:SPRandomStringLength];
        
        // Calculate the delta string
        NSMutableArray *diffList    = [dmp diff_mainOfOldString:post.title andNewString:newTitle];
        if (diffList.count > 2) {
            [dmp diff_cleanupSemantic:diffList];
            [dmp diff_cleanupEfficiency:diffList];
        }
    
        // Construct the patch delta and return it as a change operation
        NSString *delta = [dmp diff_toDelta:diffList];
        
        // Prepare the change itself
        NSDictionary *change    = @{
            CH_CLIENT_ID        : SPRemoteClientID,
            CH_CHANGE_VERSION   : changeVersion,
            CH_START_VERSION    : startVersion,
            CH_END_VERSION      : endVersion,
            CH_KEY              : post.simperiumKey,
            CH_OPERATION        : CH_MODIFY,
            CH_VALUE            : @{
                                        titleMemberName : @{
                                                                CH_OPERATION    : CH_DATA,
                                                                CH_VALUE        : delta
                                                            }
                                    }
        };
        
        changes[post.simperiumKey]      = change;
        newTitles[post.simperiumKey]    = newTitle;
    }
    
    
    // ===================================================================================================
    // Perform Local Changes (Uncommited)
    // ===================================================================================================
    //
    for (Post *post in posts) {
        post.title = [NSString sp_makeUUID];
    }
    
    
    // ===================================================================================================
    // Process remote changes
    // ===================================================================================================
    //
	StartBlock();
    
    dispatch_async(bucket.processorQueue, ^{
        [bucket.changeProcessor processRemoteChanges:changes.allValues
                                              bucket:bucket
                                        errorHandler:^(NSString *simperiumKey, NSError *error, BOOL *halt) {
                                            
                                        }];
        
		dispatch_async(dispatch_get_main_queue(), ^{
			EndBlock();
		});
    });
    
	WaitUntilBlockCompletes();
    
    // ===================================================================================================
    // Verify if the changeProcessor actually did its job
    // ===================================================================================================
    //
    for (Post *post in posts) {
        NSString *newTitle      = newTitles[post.simperiumKey];
        NSString *endVersion    = changes[post.simperiumKey][CH_END_VERSION];
        
        XCTAssert([post.title isEqualToString:newTitle],    @"Invalid Post Title");
        XCTAssert([post.ghost.version isEqual:endVersion],  @"Invalid Ghost Version");
    }
}

@end
