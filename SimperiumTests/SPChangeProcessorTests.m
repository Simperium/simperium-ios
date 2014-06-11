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

static NSInteger const SPNumberOfEntities       = 100;
static NSString * const SPRemoteClientID        = @"OSX-Remote!";
static NSUInteger const SPRandomStringLength    = 1000;


#pragma mark ====================================================================================
#pragma mark SPChangeProcessorTests
#pragma mark ====================================================================================

@interface SPChangeProcessorTests : XCTestCase

@end

@implementation SPChangeProcessorTests

- (void)testApplyRemoteDiffWithUncommitedChanges
{
    // ===================================================================================================
	// Helpers
    // ===================================================================================================
    //
	MockSimperium* s                    = [MockSimperium mockSimperium];
	SPBucket* bucket                    = [s bucketForName:NSStringFromClass([Post class])];
	SPCoreDataStorage* storage          = bucket.storage;
	NSMutableArray* posts               = [NSMutableArray array];
	NSString *titleMemberName           = NSStringFromSelector(@selector(title));
    DiffMatchPatch *dmp                 = [[DiffMatchPatch alloc] init];
    NSMutableDictionary *changes        = [NSMutableDictionary dictionary];
    NSMutableDictionary *originalTitles = [NSMutableDictionary dictionary];
    NSString *remoteTitleFormat         = @"REMOTE PREPEND\n%@\nREMOTE APPEND";
    NSString *localTitleFormat          = @"LOCAL  PREPEND\n%@\nLOCAL  APPEND";
    
    
    // ===================================================================================================
	// Insert Posts
    // ===================================================================================================
    //
	for (NSInteger i = 0; ++i <= SPNumberOfEntities; ) {
        NSString *originalTitle         = [NSString sp_randomStringOfLength:SPRandomStringLength];
        
        // New post please!
		Post* post                      = [storage insertNewObjectForBucketName:bucket.name simperiumKey:nil];
		post.title                      = originalTitle;
        
        // Manually Intialize SPGhost: we're not relying on the backend to confirm these additions!
        NSMutableDictionary *memberData = [post.dictionary mutableCopy];
        SPGhost *ghost                  = [[SPGhost alloc] initWithKey:post.simperiumKey memberData:memberData];
        ghost.version                   = @"1";
        post.ghost                      = ghost;
        post.ghostData                  = [memberData sp_JSONString];
        
        // Keep a copy of the original title
        NSString *key                   = post.simperiumKey;
        originalTitles[key]             = originalTitle;
        
        // And keep a reference to the post
		[posts addObject:post];
	}

	[storage save];
    
    NSLog(@"<> Successfully inserted %d objects", (int)SPNumberOfEntities);
    
    
    // ===================================================================================================
    // Prepare Remote Changes
    // ===================================================================================================
    //
    for (Post *post in posts) {
        NSString *changeVersion     = [NSString sp_makeUUID];
        NSString *startVersion      = post.ghost.version;
        NSString *endVersion        = [NSString stringWithFormat:@"%d", startVersion.intValue + 1];
        NSString *newTitle          = [NSString stringWithFormat:remoteTitleFormat, post.title];
        
        // Calculate the delta between the old and nu title's
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
        
        changes[post.simperiumKey] = change;
    }
    
    NSLog(@"<> Successfully generated remote changes");
    

    // ===================================================================================================
    // Perform Local Changes
    // ===================================================================================================
    //
    for (Post *post in posts) {
        NSString *newTitle = [NSString stringWithFormat:localTitleFormat, post.title];
        post.title = newTitle;
    }

    [storage save];
    
    NSLog(@"<> Successfully performed local changes");
    
    
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
    
    NSLog(@"<> Finished processing remote changes");
    
    
    // ===================================================================================================
    // Verify if the changeProcessor actually did its job
    // ===================================================================================================
    //
    for (Post *post in posts) {
        NSDictionary *change    = changes[post.simperiumKey];
        NSString *endVersion    = change[CH_END_VERSION];
        
        // Rebuild the expected Post Title
        NSString *originalTitle = originalTitles[post.simperiumKey];
        NSString *expectedTitle = [NSString stringWithFormat:localTitleFormat, originalTitle];
        expectedTitle           = [NSString stringWithFormat:remoteTitleFormat, expectedTitle];
        
        // THE check!
        XCTAssert([post.title isEqualToString:expectedTitle], @"Invalid Post Title");
        XCTAssert([post.ghost.version isEqual:endVersion], @"Invalid Ghost Version");
    }
}

@end
