//
//  SimperiumTests.m
//  SimperiumTests
//
//  Created by Michael Johnston on 11-04-19.
//  Copyright 2011 Simperium. All rights reserved.
//

#import "SimperiumTests.h"
#import "SPGhost.h"
#import "DDLog.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "JSONKit.h"
#import "NSString+Simperium.h"
#import "Config.h"
#import "Farm.h"
#import "SPBucket.h"
#import "SPSimpleKeychain.h"
#import "SPAuthenticationManager.h"

@implementation SimperiumTests
@synthesize token;
@synthesize overrides;

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

- (void)waitFor:(NSTimeInterval)seconds
{
    NSDate	*timeoutDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
    NSLog(@"Waiting for %f seconds...", seconds);
	do {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
		if([timeoutDate timeIntervalSinceNow] < 0.0)
			break;
        
	} while (YES);
    
	return;
}

- (BOOL)farmsDone:(NSArray *)farmArray
{
    for (Farm *farm in farmArray) {
        if (![farm isDone]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)waitForCompletion:(NSTimeInterval)timeoutSecs farmArray:(NSArray *)farmArray
{
    // Don't wait if everything is done already
    if ([self farmsDone:farmArray])
        return YES;
    
	NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeoutSecs];
    done = NO;
    
	do {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
		if([timeoutDate timeIntervalSinceNow] < 0.0)
			break;
        
        // We're done when all the farms are done
        done = [self farmsDone: farmArray];

	} while (!done);
    
    // If it timed out, try to log why
    if([timeoutDate timeIntervalSinceNow] < 0.0) {
        for (Farm *farm in farmArray) {
            [farm logUnfulfilledExpectations];
        }
    }
    
    // Wait an extra little tick so things like GET long polling have a chance to reestablish
    [self waitFor:0.1];
    
	return done;
}

- (BOOL)waitForCompletion {
    return [self waitForCompletion:3.0+NUM_FARMS*3 farmArray:farms];
}

- (NSString *)uniqueBucketFor:(NSString *)entityName {
    NSString *bucketSuffix = [[NSString sp_makeUUID] substringToIndex:8];
    NSString *bucket = [NSString stringWithFormat:@"%@-%@", entityName, bucketSuffix];
    return bucket;
}

- (NSDictionary *)bucketOverrides {
    // Implemented by subclasses
    return nil;
}

- (Farm *)createFarm:(NSString *)label {
    Farm *farm = [[[Farm alloc] initWithToken: token bucketOverrides:[self bucketOverrides] label:label] autorelease];
    return farm;
}

- (void)createFarms {
    farms = [[NSMutableArray arrayWithCapacity:NUM_FARMS] retain];
    
    // Use a different bucket for each test so it's always starting fresh
    // (We should periodically Delete All Data in the test app to clean stuff up)
    
    for (int i=0; i<NUM_FARMS; i++) {
        NSString *label = [NSString stringWithFormat:@"client%d", i];
        Farm *farm = [self createFarm: label];
        [farms addObject:farm];
    }
}

- (void)startFarms {    
    for (int i=0; i<NUM_FARMS; i++) {
        Farm *farm = [farms objectAtIndex:i];
        [farm start];
    }
}

- (void)createAndStartFarms {
    [self createFarms];
    [self startFarms];
}

- (void)setUp
{
    [super setUp];
    // Set the token
    //NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/app/%@/token/?grant_type=password&api_key=%@&username=%@&password=%@", SERVER, APP_NAME, ACCESS_KEY, USERNAME, PASSWORD]];
    NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/1/%@/authorize/", SERVER, APP_ID]];
    
    ASIFormDataRequest *tokenRequest = [[ASIFormDataRequest alloc] initWithURL:tokenURL];
    [tokenRequest setPostValue:USERNAME forKey:@"username"];
    [tokenRequest setPostValue:PASSWORD forKey:@"password"];
    [tokenRequest setPostValue:API_KEY forKey:@"api_key"];
    //[tokenRequest setRequestMethod:@"POST"];
    [tokenRequest startSynchronous];
    NSString *tokenResponse = [tokenRequest responseString];
    int code = [tokenRequest responseStatusCode];
    STAssertTrue(code == 200, @"bad response code %d for request %@, response: %@", code, tokenURL, tokenResponse);
    if (code != 200)
        return;
        
    NSDictionary *userDict = [tokenResponse objectFromJSONString];
    
    self.token = [userDict objectForKey:@"access_token"];
    STAssertTrue(token.length > 0, @"invalid token from request: %@", tokenURL);
    
    [[NSUserDefaults standardUserDefaults] setObject: token forKey:@"spAuthToken"];
    NSMutableDictionary *credentials = [SPSimpleKeychain load:APP_ID];
    if (!credentials)
        credentials = [NSMutableDictionary dictionary];
    [credentials setObject:token forKey:@"SPAuthToken"];
    [SPSimpleKeychain save:APP_ID data: credentials];

    NSLog(@"auth token is %@", self.token);
}

- (void)tearDown
{
    [farms release];
    [overrides release];
    [super tearDown];
}

//- (void)ensureConfigsAreEqualTo:(Farm *)leader
//{
//    for (Farm *farm in farms) {
//        if (farm == leader)
//            continue;
//        farm.config = (Config *)[farm.simperium objectForKey:@"config" entityName:@"Config"];
//        STAssertTrue([farm.config isEqualToConfig:leader.config], @"config %@ != leader %@", farm.config, leader.config);
//    }
//}


- (void)ensureFarmsEqual: (NSArray *)farmArray entityName:(NSString *)entityName
{
    // Assume all leader configs are the same since they're set manually
    Farm *leader = [farmArray objectAtIndex:0];
    NSArray *leaderObjects = [[leader.simperium bucketForName:entityName] allObjects] ;
    STAssertTrue([leaderObjects count] > 0, @"");
    
    //Config *leaderConfig = [leaderConfigs objectAtIndex:0];
    if ([leaderObjects count] == 0)
        return;
    
    for (Farm *farm in farmArray) {
        if (farm == leader)
            continue;
        
        NSArray *objects = [[farm.simperium bucketForName:entityName] allObjects];
        STAssertEquals([leaderObjects count], [objects count], @"");

        // Make sure each key was synced
        NSMutableDictionary *objectDict = [NSMutableDictionary dictionaryWithCapacity:[leaderObjects count]];
        for (TestObject *object in objects) {
            [objectDict setObject:object forKey:object.simperiumKey];
        }
        
        // Make sure each synced object is equal to the leader's objects
        for (TestObject *leaderObject in leaderObjects) {
            TestObject *object = [objectDict objectForKey:leaderObject.simperiumKey];
            //STAssertTrue([object.ghost.version isEqualToString: leaderObject.ghost.version],
            //             @"version %@ != leader version %@", object.ghost.version, leaderObject.ghost.version );
            STAssertTrue([object isEqualToObject:leaderObject], @"follower %@ != leader %@", object, leaderObject);
            
            // Removed ghostData check since JSONKit doesn't necessarily parse in the same order, so strings will differ
            //STAssertTrue([[object.ghostData isEqualToString:leaderObject.ghostData],
            //             @"\n\follower.ghostData %@ != \n\tleader.ghostData %@", object.ghostData, leaderObject.ghostData);
        }
    }
}

- (void)connectFarms
{
    for (Farm *farm in farms)
        [farm connect];
    // Wait a jiffy (there are no callbacks for the first GET because there don't need to be)
    // Could skip this to test offline changes
    [self waitFor:1.0];
}

- (void)disconnectFarms
{
    for (Farm *farm in farms)
        [farm disconnect];
}

// Tell farms what to expect so it's possible to wait for async networking to complete
- (void)expectAdditions:(int)additions deletions:(int)deletions changes:(int)changes fromLeader:(Farm *)leader expectAcks:(BOOL)expectAcks
{
    if (expectAcks) {
        int acknowledgements = additions + deletions + changes;
        leader.expectedAcknowledgments += acknowledgements;
    } else
        leader.expectedAcknowledgments = 0;
        
    for (Farm *farm in farms) {
        if (farm == leader)
            continue;
        farm.expectedAcknowledgments = 0;
        farm.expectedAdditions += additions;
        farm.expectedDeletions += deletions;
        farm.expectedChanges += changes;
    }
}

- (void)resetExpectations:(NSArray *)farmArray
{
    for (Farm *farm in farmArray) {
        farm.expectedAcknowledgments = 0;
        farm.expectedAdditions = 0;
        farm.expectedChanges = 0;
        farm.expectedDeletions = 0;
    }
}

@end