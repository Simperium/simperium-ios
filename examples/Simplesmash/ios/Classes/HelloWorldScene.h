//
//  HelloWorldLayer.h
//


// When you import this file, you import all the cocos2d classes
#import "cocos2d.h"
#import <Simperium/Simperium.h>

@class SneakyJoystick;
@class SneakyButton;
@class Player;

// HelloWorld Layer
@interface HelloWorld : CCLayer <SimperiumDelegate>
{
	SneakyJoystick *leftJoystick;
	SneakyButton *rightButton;
    Player *player;
    CCNode *background;
}

@property (nonatomic, retain) Player *player;
@property (nonatomic, retain) CCNode *background;

// returns a Scene that contains the HelloWorld as the only child
+(id) scene;


@end
