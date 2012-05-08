//
//  Player.h
//  Simplesmash
//
//  Created by Michael Johnston on 12-04-20.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <Simperium/SPManagedObject.h>

#define TILE_SIZE_X 100
#define TILE_SIZE_Y 80

@class CCNode;

@interface Player : SPManagedObject {
    CCNode *sprite;
    float speed;
    BOOL moving;
    BOOL controlling;
}

@property (nonatomic, retain) NSNumber * tileX;
@property (nonatomic, retain) NSNumber * tileY;
@property (nonatomic, retain) NSNumber * destinationX;
@property (nonatomic, retain) NSNumber * destinationY;
@property (nonatomic, assign) CCNode * sprite;
@property (nonatomic, assign) BOOL moving;

-(void)setTileX:(int)x tileY:(int)y;
-(BOOL)processInputVelocity:(CGPoint)inputVelocity;
-(BOOL)update:(float)delta;

@end
