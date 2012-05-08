//
//  HelloWorldLayer.m
//

// Import the interfaces
#import "HelloWorldScene.h"
#import "SimplesmashAppDelegate.h"
#import "SneakyJoystick.h"
#import "SneakyJoystickSkinnedJoystickExample.h"
#import "SneakyJoystickSkinnedDPadExample.h"
#import "SneakyButton.h"
#import "SneakyButtonSkinnedBase.h"
#import "ColoredCircleSprite.h"
#import "Player.h"
#import "Viewport.h"
#import <Simperium/NSString+Simperium.h>

// HelloWorld implementation
@implementation HelloWorld
@synthesize player;
@synthesize background;

ColoredCircleSprite *playerSprite;

+(id) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	HelloWorld *layer = [HelloWorld node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

-(void)configurePlayer {
    playerSprite = [CCSprite spriteWithFile:@"boy.png"];//[ColoredCircleSprite circleWithColor:ccc4(0, 0, 255, 128) radius:32];
    [playerSprite setAnchorPoint:CGPointMake(0, 0)];
    [self.background addChild:playerSprite];

    player.sprite = playerSprite;
}

-(NSString *)hashedUDID {
    // Since uniqueIdentifier is deprecated, this should ideally use some other form of unique ID instead
    // (the warning can be safely ignored since this is just an example)
    NSString *udid = [[UIDevice currentDevice] uniqueIdentifier];
    return [NSString md5StringFromData:[udid dataUsingEncoding:NSUTF8StringEncoding]];
}

-(Viewport *)viewport {
    SimplesmashAppDelegate *appDelegate = (SimplesmashAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *udid = [self hashedUDID];
    Viewport *viewport = (Viewport *)[appDelegate.simperium objectForKey:udid entityName:@"Viewport"];
    return viewport;
}

-(void)updateViewport {
    // Update the viewport smoothly
    Viewport *viewport = [self viewport];
    int x = [viewport.x integerValue];
    int y = [viewport.y integerValue];
    CCMoveTo *moveViewport = [CCMoveTo actionWithDuration:0.1 position:CGPointMake(-x, -y)];
    [self.background stopAllActions];
    [self.background runAction:moveViewport];
}

-(id) init
{
	if ((self = [super init])) {
        
		self.isTouchEnabled = YES;
		
        // Configure the dpad
		SneakyJoystickSkinnedBase *leftJoy = [[[SneakyJoystickSkinnedBase alloc] init] autorelease];
		leftJoy.position = ccp(64,64);
		leftJoy.backgroundSprite = [CCSprite spriteWithFile:@"joystickpad.png"];
		leftJoy.thumbSprite = [CCSprite spriteWithFile:@"joystickbutton.png"];
		leftJoy.joystick = [[SneakyJoystick alloc] initWithRect:CGRectMake(0,0,128,128)];
		leftJoystick = [leftJoy.joystick retain];
        leftJoystick.isDPad = YES;
		[self addChild:leftJoy z:99];
		
		SneakyButtonSkinnedBase *rightBut = [[[SneakyButtonSkinnedBase alloc] init] autorelease];
		rightBut.position = ccp(280,32);
		rightBut.defaultSprite = [ColoredCircleSprite circleWithColor:ccc4(255, 255, 255, 128) radius:32];
		rightBut.activatedSprite = [ColoredCircleSprite circleWithColor:ccc4(255, 255, 255, 255) radius:32];
		rightBut.pressSprite = [ColoredCircleSprite circleWithColor:ccc4(255, 0, 0, 255) radius:32];
		rightBut.button = [[SneakyButton alloc] initWithRect:CGRectMake(0, 0, 64, 64)];
		rightButton = [rightBut.button retain];
		rightButton.isToggleable = YES;
		//[self addChild:rightBut];
        
        // Perform some init after Simperium retrieves first index
        SimplesmashAppDelegate *appDelegate = (SimplesmashAppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate.simperium addDelegate:self];

        // Create the map
        self.background = [CCTMXTiledMap tiledMapWithTMXFile:@"map.tmx"];
        [self addChild:self.background z:-1];
		[[CCDirector sharedDirector] setAnimationInterval:1.0f/60.0f];
        [[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:NO];
        
        // If the player exists already, configure it
        self.player = (Player *)[appDelegate.simperium objectForKey:@"player1" entityName:@"Player"];
        if (player)
            [self configurePlayer];

        // If the viewport exists already, configure it
        Viewport *viewport = [self viewport];
        if (viewport)
            [self updateViewport];
		
        // Tick!
        [self schedule:@selector(tick:) interval:1.0f/120.0f];
	}
	return self;
}

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event { 
    return TRUE;
}

-(void) ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    // Allow local changes to the viewport by touching and dragging; save when dragging completes
    Viewport *viewport = [self viewport];
    viewport.x = [NSNumber numberWithInt:-self.background.position.x];
    viewport.y = [NSNumber numberWithInt:-self.background.position.y];

    SimplesmashAppDelegate *appDelegate = (SimplesmashAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.simperium save];
}

- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event {  
    CGPoint touchLocation = [self convertTouchToNodeSpace:touch];

    // Ignore joystick touches
    if (touchLocation.x < 130 && touchLocation.y < 130 )
        return;

    // Move the map when dragging
    CGPoint oldTouchLocation = [touch previousLocationInView:touch.view];
    oldTouchLocation = [[CCDirector sharedDirector] convertToGL:oldTouchLocation];
    oldTouchLocation = [self convertToNodeSpace:oldTouchLocation];
    
    CGPoint translation = ccpSub(touchLocation, oldTouchLocation); 
    
    CGPoint newPos = ccpAdd(self.background.position, translation);
    self.background.position = newPos;
}

-(void)indexingDidFinish:(NSString *)entityName {
    // This gets called when the app is launched for the first time
    SimplesmashAppDelegate *appDelegate = (SimplesmashAppDelegate *)[[UIApplication sharedApplication] delegate];

    if ([entityName isEqualToString:@"Player"]) {
        // If the player still doesn't exist (not even created elsewhere), create it
        self.player = (Player *)[appDelegate.simperium objectForKey:@"player1" entityName:@"Player"];
        if (!player) {
            self.player = [NSEntityDescription insertNewObjectForEntityForName:@"Player" inManagedObjectContext:appDelegate.managedObjectContext];
            self.player.simperiumKey = @"player1";
            [appDelegate saveContext];
        }
        [self configurePlayer];
    } else {    
        // If the viewport for this device doesn't exist, create it and mark it with a hashed UDID    
        Viewport *viewport = [self viewport];
        if (!viewport) {
            NSString *udid = [self hashedUDID];
            viewport = [NSEntityDescription insertNewObjectForEntityForName:@"Viewport" inManagedObjectContext:appDelegate.managedObjectContext];
            viewport.simperiumKey = udid;
            BOOL portrait = [[UIDevice currentDevice] orientation] == kCCDeviceOrientationPortrait || 
                [[UIDevice currentDevice] orientation] == kCCDeviceOrientationPortraitUpsideDown;
            viewport.orientation = portrait ? @"portrait" : @"landscape";
            viewport.kind = UIUserInterfaceIdiomPhone == UI_USER_INTERFACE_IDIOM() ?  @"iphone" : @"ipad";
            [appDelegate saveContext];
        }
    }
}

-(void)objectKeysChanged:(NSSet *)keyArray entityName:(NSString *)entityName {
    // When the viewport is reconfigured in the web app, update it here
    Viewport *viewport = [self viewport];
    for (NSString *key in keyArray) {
        if ([key isEqualToString:viewport.simperiumKey]) {
            [self updateViewport];
        }
    }
}

-(void)tick:(float)delta {
    SimplesmashAppDelegate *appDelegate = (SimplesmashAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // Handle player controls
    if ([player update:delta] || [player processInputVelocity:leftJoystick.velocity]) {
        // Save changes when necessary
        [appDelegate saveContext];
    }
}

- (void) dealloc
{
	self.player = nil;    
	[super dealloc];
}


@end
