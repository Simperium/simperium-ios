//
//  SPManagedObject.h
//
//  Created by Michael Johnston on 11-02-11.
//  Copyright 2011 Simperium. All rights reserved.
//

// You shouldn't need to call any methods or access any properties directly in this class. Feel free to browse though.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SPMember;
@class SPGhost;
@class SPEntityDefinition;
@class SPObjectManager;

@interface SPManagedObject : NSManagedObject {
	// The entity's member data as last seen by the server, stored in dictionary form for diffing
	// has key, data, and signature
	SPGhost *ghost;
    SPEntityDefinition *definition;
    
    NSString *simperiumKey;
    NSString *ghostData;
	
	// Flagged if changed while waiting for server ack (could be tracked externally instead)
	BOOL updateWaiting;
}

@property (retain, nonatomic) SPGhost *ghost;
@property (assign, nonatomic) SPEntityDefinition *definition;
@property (copy, nonatomic) NSString *ghostData;
@property (copy, nonatomic) NSString *simperiumKey;
@property (assign, nonatomic) BOOL updateWaiting;

+(void)initDefinitions:(NSDictionary *)definitions;
-(void)loadMemberData:(NSDictionary *)dictionary;
-(NSDictionary *)dictionary;
-(NSMutableDictionary *)diffForAddition;
-(NSDictionary *)diffWithDictionary:(NSDictionary *)dict;
-(void)applyDiff:(NSDictionary *)diff;
-(void)applyGhostDiff:(NSDictionary *)diff;
-(NSDictionary *)transformDiff:(NSDictionary *)diff oldDiff:(NSDictionary *)oldDiff oldGhost:(SPGhost *)oldGhost;
-(NSString *)version;

@end
