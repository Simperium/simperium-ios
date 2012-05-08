//
//  Player.m
//  Simplesmash
//
//  Created by Michael Johnston on 12-04-20.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "Player.h"
#import "CCNode.h"
#import "cocos2d.h"

@implementation Player

@dynamic destinationX;
@dynamic destinationY;
@dynamic tileX;
@dynamic tileY;
@synthesize sprite;
@synthesize moving;

-(void)configure {
    // Quick and dirty configuration
    speed = 150.0;
}

-(void)awakeFromFetch {
    [super awakeFromFetch];
    [self configure];
}

-(void)awakeFromInsert {
    [super awakeFromInsert];
    [self configure];
    self.tileX = [NSNumber numberWithInt:1];
    self.tileY = [NSNumber numberWithInt:1];
}

-(void)setTileX:(int)x tileY:(int)y {
    // The character moves tile by tile
    self.tileX = [NSNumber numberWithInt:x];
    self.tileY = [NSNumber numberWithInt:y];
    [sprite setPosition:CGPointMake(x*TILE_SIZE_X, y*TILE_SIZE_Y)];
}

-(void)setSprite:(CCNode *)_sprite {
    sprite = _sprite;
    int x = [self.tileX integerValue];
    int y = [self.tileY integerValue];
    [sprite setPosition:CGPointMake(x*TILE_SIZE_X, y*TILE_SIZE_Y)];
}

-(BOOL)update:(float) delta {
    // This is an overly simple but functional way to update the character's location
    
    int destX = [self.destinationX integerValue];
    int destY = [self.destinationY integerValue];
    BOOL needsSave = NO;

    CGPoint destPixels = CGPointMake(destX*TILE_SIZE_X, destY*TILE_SIZE_Y);
    CGPoint srcPixels = self.sprite.position;
    CGPoint dir = ccpSub(destPixels, srcPixels);
    
    // If the destination is far away, teleport
    // (this is a quick and dirty way to kill the player from a service)
    if (ccpLength(dir) > 300) {
        moving = NO;
        controlling = NO;
        [self setTileX:destX tileY:destY];
    } else if (ccpFuzzyEqual(srcPixels, destPixels, 5.0) && moving) {
        // If the destination has been reached, stopped
        [self setTileX:destX tileY:destY];
        if (controlling)
            needsSave = YES;
        moving = NO;
        controlling = NO;
    } else if (ccpLength(dir) > 3) {
        // Otherwise, move towards it
        moving = YES;
        CGPoint norm = ccpNormalize(dir);
        CGPoint move = ccpMult(norm, speed*delta);
        CGPoint newDest = ccpAdd(srcPixels, move);
        //NSLog(@"Moving to %f, %f", newDest.x, newDest.y);

        [self.sprite setPosition:newDest];
    }
    
    return needsSave;
}

-(BOOL)processInputVelocity:(CGPoint)inputVelocity {
    if (ccpLength(inputVelocity) != 0 && !moving) {
        // Figure out the destination tile based on the joystick's inputVelocity
        int destX = [self.tileX integerValue] + (int)inputVelocity.x;
        int destY = [self.tileY integerValue] + (int)inputVelocity.y;
        
        if ([self.destinationX integerValue] != destX || [self.destinationY integerValue] != destY) {
            //NSLog(@"New destination: %d, %d", destX, destY);
            self.destinationX = [NSNumber numberWithInt:destX];
            self.destinationY = [NSNumber numberWithInt:destY];
            controlling = YES;
            return YES;
        }
    }
    return NO;
}

@end
