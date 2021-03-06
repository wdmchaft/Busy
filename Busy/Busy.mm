//
//  Busy.mm
//  Busy
//
//  Created by Saida Memon on 3/8/12.
//  Copyright __MyCompanyName__ 2012. All rights reserved.
//


// Import the interfaces
#import "Busy.h"
#import "GameOverScene.h"
#import "MyContactListener.h"

//Pixel to metres ratio. Box2D uses metres as the unit for measurement.
//This ratio defines how many pixels correspond to 1 Box2D "metre"
//Box2D is optimized for objects of 1x1 metre therefore it makes sense
//to define the ratio so that your most common object type is 1x1 metre.
#define PTM_RATIO 32

// enums that will be used as tags
enum {
	kTagTileMap = 1,
	kTagBatchNode = 1,
	kTagAnimation1 = 1,
};


/** Convert the given position into the box2d world. */
static inline float ptm(float d)
{
    return d / PTM_RATIO;
}

/** Convert the given position into the cocos2d world. */
static inline float mtp(float d)
{
    return d * PTM_RATIO;
}


// Busy implementation
@implementation Busy

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	Busy *layer = [Busy node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}


-(id)init

{
    
    if( (self=[super init])) { 
        
        // enable touches
        self.isTouchEnabled = YES; 
        
        // enable accelerometer
        self.isAccelerometerEnabled = YES; 
        
        CGSize screenSize = [CCDirector sharedDirector].winSize;
        //CCLOG(@"Screen width %0.2f screen height %0.2f",screenSize.width,screenSize.height); 
        
        //initial settings
        score  = 0;
        highscore = 0;
        stopWater = TRUE;
        muted = FALSE;
        [self restoreData];
        
        // Define the gravity vector.
        b2Vec2 gravity;
        gravity.Set(0.0f, -10.0f); 
            
        // This will speed up the physics simulation
        bool doSleep = true; 
        
        // Construct a world object, which will hold and simulate the rigid bodies.
        world = new b2World(gravity, doSleep); 
        world->SetContinuousPhysics(true); 
        
   /*     // Debug Draw functions
        m_debugDraw = new GLESDebugDraw( PTM_RATIO );
        world->SetDebugDraw(m_debugDraw); 
        uint32 flags = 0;
        flags += b2DebugDraw::e_shapeBit;
        m_debugDraw->SetFlags(flags);  
        */
        
        ground = NULL;
        b2BodyDef bd;
        ground = world->CreateBody(&bd);
        
        bodyDef.type=b2_dynamicBody;
        
        // Define the static container body, which will provide the collisions at screen borders.
        b2BodyDef containerBodyDef;
        b2Body* containerBody = world->CreateBody(&containerBodyDef);
        
        // for the ground body we'll need these values
        float widthInMeters = screenSize.width / 32.0f;
        float heightInMeters = screenSize.height / 32.0f;
        b2Vec2 lowerLeftCorner = b2Vec2(0, 0);
        b2Vec2 lowerRightCorner = b2Vec2(widthInMeters, 0);
        b2Vec2 upperLeftCorner = b2Vec2(0, heightInMeters);
        b2Vec2 upperRightCorner = b2Vec2(widthInMeters, heightInMeters);
        
        // Create the screen box' sides by using a polygon assigning each side individually.
        b2PolygonShape screenBoxShape;
        int density = 0;
        
        // left side
        screenBoxShape.SetAsEdge(upperLeftCorner, lowerLeftCorner);
        _leftFixture =containerBody->CreateFixture(&screenBoxShape, density);
        
        // right side
        screenBoxShape.SetAsEdge(upperRightCorner, lowerRightCorner);
        _rightFixture =containerBody->CreateFixture(&screenBoxShape, density);
        
        
        // bottom
        screenBoxShape.SetAsEdge(lowerLeftCorner, lowerRightCorner);
        containerBody->CreateFixture(&screenBoxShape, density);
        
        // top
        screenBoxShape.SetAsEdge(upperLeftCorner, upperRightCorner);
        containerBody->CreateFixture(&screenBoxShape, density);
        
        
        groundWalls = [[NSArray alloc] initWithObjects: 
                 [NSValue valueWithPointer:_leftFixture],
                 [NSValue valueWithPointer:_rightFixture], nil];
        
        
        //show scores
        highscoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"HighScore: %i",highscore] fontName:@"Marker Felt" fontSize:24];
        //highscoreLabel.color = ccc3(26, 46, 149);
        highscoreLabel.color = ccBLUE;
        highscoreLabel.position = ccp(180.0f, 465.0f);
        [self addChild:highscoreLabel z:10];
        
        scoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"       Score: %i",score] fontName:@"Marker Felt" fontSize:24];
        scoreLabel.position = ccp(180.0f, 445.0f);
        //scoreLabel.color = ccc3(26, 46, 149);
        scoreLabel.color = ccBLUE;
        [self addChild:scoreLabel z:10];
        
        
        // Preload effect
        [MusicHandler preload];
        
        [[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
        
        //Pause Toggle can not sure frame cache for sprites!!!!!
		CCMenuItemSprite *playItem = [CCMenuItemSprite itemFromNormalSprite:[CCSprite spriteWithFile:@"newPauseON.png"]
                                                             selectedSprite:[CCSprite spriteWithFile:@"newPauseONSelect.png"]];
        
		CCMenuItemSprite *pauseItem = [CCMenuItemSprite itemFromNormalSprite:[CCSprite spriteWithFile:@"newPauseOFF.png"]
                                                              selectedSprite:[CCSprite spriteWithFile:@"newPauseOFFSelect.png"]];
        
		if (!muted)  {
            pause = [CCMenuItemToggle itemWithTarget:self selector:@selector(turnOnMusic)items:playItem, pauseItem, nil];
            pause.position = ccp(screenSize.width*0.03, screenSize.height*0.95f);
        }
        else {
            pause = [CCMenuItemToggle itemWithTarget:self selector:@selector(turnOnMusic)items:pauseItem, playItem, nil];
            pause.position = ccp(screenSize.width*0.03, screenSize.height*0.95f);
        }
        
		//Create Menu with the items created before
		CCMenu *menu = [CCMenu menuWithItems:pause, nil];
		menu.position = CGPointMake(10.0f, 7.5f);
		[self addChild:menu z:11];
        
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"bally.plist"];
        CCSpriteBatchNode*  spriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"bally.png"];
        [self addChild:spriteSheet];
       // [[CCTextureCache sharedTextureCache] addImage:@"bricks.png" ]; 
       // texture = [[CCTextureCache sharedTextureCache] addImage:@"bricks.png"];
        
        contactListener = new MyContactListener();
        world->SetContactListener(contactListener);
        
        [self setupBoard];
        [self setupLevels];

        [self schedule: @selector(tick:)]; 
    }
    return self; 
}

-(void)setupLevels {
    
    level1 = FALSE;
    level2 = FALSE;
    level3 = FALSE;
    level4 = FALSE;
    level5 = FALSE;
    level6 = FALSE;
    
    
    //float Xdelta = 2.0;
    float Ydelta = 2.0f;
    float Xinit = 2.3f;
    float Yinit = 2.0;
    
    walls = [[NSMutableArray alloc] initWithCapacity:18];

    for (int i = 0; i <7; i++) {
        //if (i < 5)[self createWall:Xinit + (i *Xdelta) where:Yinit + (i*Ydelta)];
        //else         [self createWall:Xinit +1.0f where:Yinit + (5*Ydelta)];
        if (i < 5)[self createWall:Xinit + (arc4random()% 7) where:Yinit + (i*Ydelta)];
        else         [self createWall:Xinit +arc4random() % 1 where:Yinit + (5*Ydelta)];
    }
    /*    [self createWall:3.3f where:13.5f];
     [self createWall:3.3f where:11.5f];
     [self createWall:2.3f where:9.5f];
     [self createWall:4.3f where:7.5f];
     [self createWall:6.3f where:5.5f];
     [self createWall:8.3f where:3.5f];
     */  
}


- (CCAction*)createBlinkAnim:(BOOL)isTarget {
    NSMutableArray *walkAnimFrames = [NSMutableArray array];
    
    [walkAnimFrames addObject:[[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:@"dogC1.png"]];
    [walkAnimFrames addObject:[[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:@"dogC2.png"]];
    
    CCAnimation *walkAnim = [CCAnimation animationWithFrames:walkAnimFrames delay:0.1f];
    
    CCAnimate *blink = [CCAnimate actionWithDuration:0.2f animation:walkAnim restoreOriginalFrame:YES];
    
    CCAction *walkAction = [CCRepeatForever actionWithAction:
                            [CCSequence actions:
                             [CCDelayTime actionWithDuration:CCRANDOM_0_1()*2.0f],
                             blink,
                             [CCDelayTime actionWithDuration:CCRANDOM_0_1()*3.0f],
                             blink,
                             [CCDelayTime actionWithDuration:CCRANDOM_0_1()*0.2f],
                             blink,
                             [CCDelayTime actionWithDuration:CCRANDOM_0_1()*2.0f],
                             nil]
                            ];
    
    return walkAction;
}

- (CCAction*)createEyesBlinkAnim:(BOOL)isTarget {
    NSMutableArray *walkAnimFrames = [NSMutableArray array];
    
    [walkAnimFrames addObject:[[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:@"eyesA1.png"]];
    [walkAnimFrames addObject:[[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:@"eyesA2.png"]];
    
    CCAnimation *walkAnim = [CCAnimation animationWithFrames:walkAnimFrames delay:0.1f];
    
    CCAnimate *blink = [CCAnimate actionWithDuration:0.2f animation:walkAnim restoreOriginalFrame:YES];
    
    CCAction *walkAction = [CCRepeatForever actionWithAction:
                            [CCSequence actions:
                             [CCDelayTime actionWithDuration:CCRANDOM_0_1()*2.0f],
                             blink,
                             [CCDelayTime actionWithDuration:CCRANDOM_0_1()*3.0f],
                             blink,
                             [CCDelayTime actionWithDuration:CCRANDOM_0_1()*0.2f],
                             blink,
                             [CCDelayTime actionWithDuration:CCRANDOM_0_1()*2.0f],
                             nil]
                            ];
    
    return walkAction;
}


-(void)setupBoard {
    
/*    //background
    sprite = [CCSprite spriteWithFile:@"back.png"];
    sprite.anchorPoint = CGPointZero;
    sprite.position = CGPointZero;
    [self addChild:sprite z:-11];
  */  
    //circle1
    //sprite = [CCSprite spriteWithSpriteFrameName:@"ball.png"];
    ballSprite = [CCSprite spriteWithSpriteFrameName:@"dogC1.png"];
    ballSprite.position = ccp(480.0f/2, 50/PTM_RATIO);
    ballSprite.scale =0.8;
    [self addChild:ballSprite z:4 tag:11];
    [ballSprite runAction:[self createBlinkAnim:YES]];

    ballBodyDef.type = b2_dynamicBody;
    ballBodyDef.userData = ballSprite;
    ballBodyDef.position.Set(1.47f, 14.5f);
    ball = world->CreateBody(&ballBodyDef);
    circleShape.m_radius = (ballSprite.contentSize.width / 32.0f) * 0.3f;
    fixtureDef.shape = &circleShape;
    fixtureDef.density = 5.0f*CC_CONTENT_SCALE_FACTOR();
    fixtureDef.friction = 0.0f;
    fixtureDef.restitution = 0.4f;
    _ballFixture = ball->CreateFixture(&fixtureDef);
        
    //Hole
    CCSprite *holeSprite = [CCSprite spriteWithSpriteFrameName:@"house.png"];
    holeSprite.position = ccp(480.0f/2, 50/PTM_RATIO);
    [self addChild:holeSprite z:-1 tag:99];
    bodyDef.userData = holeSprite;
    bodyDef.position.Set(8.0f, 0.5f);
    bodyDef.type = b2_staticBody;
    hole = world->CreateBody(&bodyDef);
    circleShape.m_radius = (holeSprite.contentSize.width / 32.0f) * 0.05f;
    fixtureDef.shape = &circleShape;
    fixtureDef.density = 1.0f*CC_CONTENT_SCALE_FACTOR();
    fixtureDef.friction = 0.0f;
    fixtureDef.restitution = 0.0f;
    fixtureDef.isSensor = true;
    hole->CreateFixture(&fixtureDef);
    
    //Door
    CCSprite *doorSprite = [CCSprite spriteWithSpriteFrameName:@"bone.png"];
    doorSprite.position = ccp(480.0f/2, 50/PTM_RATIO);
    [self addChild:doorSprite z:-1 tag:88];
    bodyDef.userData = doorSprite;
    bodyDef.position.Set(2.0f, 0.5f);
    bodyDef.type = b2_staticBody;
    door = world->CreateBody(&bodyDef);
    circleShape.m_radius = (holeSprite.contentSize.width / 32.0f) * 0.05f;
    fixtureDef.shape = &circleShape;
    fixtureDef.density = 1.0f*CC_CONTENT_SCALE_FACTOR();
    fixtureDef.friction = 0.0f;
    fixtureDef.restitution = 0.0f;
    fixtureDef.isSensor = true;
    door->CreateFixture(&fixtureDef);
}


-(void)createWall:(float)length where:(float)y {
    
    //ccTexParams params = {GL_LINEAR,GL_LINEAR,GL_REPEAT,GL_REPEAT};
    
    ballSprite = [CCSprite spriteWithSpriteFrameName:@"eyesA1.png"];
    ballSprite.position = ccp(((arc4random() % 3) + (length-2.0)*32.0)/2, y*32.0f);
    [self addChild:ballSprite z:4 tag:11];
    [ballSprite runAction:[self createEyesBlinkAnim:YES]];
    
  /*  sprite= [[CCSprite alloc] initWithTexture:texture rect:CGRectMake(0, 0, length*64.0f, 0.35*64.0f)];
    [sprite.texture setTexParameters:&params];        
    [self addChild:sprite z:3 tag:33];
    bodyDef1.userData = sprite;
   */ 
    bodyDef1.type = b2_staticBody;
    bodyDef1.position.Set(0.0f, y);
    wall = world->CreateBody(&bodyDef1);
    boxy.SetAsBox(length, 0.35f);
    fixtureDef.shape = &boxy;
    fixtureDef.density = 0.015000f;
    fixtureDef.friction = 0.300000f;
    fixtureDef.restitution = 0.600000f;
    fixtureDef.filter.groupIndex = int16(0);
    fixtureDef.filter.categoryBits = uint16(65535);
    fixtureDef.filter.maskBits = uint16(65535);        
    wall->CreateFixture(&boxy,0);
    [walls addObject:[NSValue valueWithPointer:wall]];
    
    ballSprite = [CCSprite spriteWithSpriteFrameName:@"eyesA1.png"];
    //ballSprite.position = ccp((5.8f*32.0f)+ length*32.0/2, y*32.0f);
    ballSprite.position = ccp((((arc4random() % 4) + 1.8f)*32.0f)+ length*32.0/2, y*32.0f);
    [self addChild:ballSprite z:4 tag:11];
    [ballSprite runAction:[self createEyesBlinkAnim:YES]];
    
   /* sprite= [[CCSprite alloc] initWithTexture:texture rect:CGRectMake(0, 0, 5.0f*64.0f, 0.35*64.0f)];
    [sprite.texture setTexParameters:&params];        
    [self addChild:sprite z:3 tag:33];
    bodyDef1.userData = sprite;
    */
     bodyDef1.position.Set(6.2f + length, y);
    wall = world->CreateBody(&bodyDef1);
    boxy.SetAsBox(5.0f, 0.35f);    
    fixtureDef.shape = &boxy;
    fixtureDef.density = 0.015000f;
    fixtureDef.friction = 0.300000f;
    fixtureDef.restitution = 0.600000f;
    fixtureDef.filter.groupIndex = int16(0);
    fixtureDef.filter.categoryBits = uint16(65535);
    fixtureDef.filter.maskBits = uint16(65535);        
    wall->CreateFixture(&boxy,0);
    [walls addObject:[NSValue valueWithPointer:wall]];

}

- (void)scored:(int)scorVal {
    //[MusicHandler playBounce];
    //score -= 155;
    
    if (scorVal < 0) { 
        [MusicHandler playWater];
        [self callEmitter];

    } else {
        [MusicHandler playBounce];
    }
    score += scorVal;
    [self updateScore];
}


- (void)endGame:(b2Body*)bodyB {
    if (stopWater) {
        [MusicHandler playExit];
         stopWater = FALSE;
        bodyB->SetLinearVelocity(b2Vec2(0,0));
        bodyB->SetAngularVelocity(0);
        
        [self saveData];
        [self performSelector:@selector(gotoHS) withObject:nil afterDelay:0.2];
    }
}


- (void)restartGame:(b2Body*)bodyB {
    if (stopWater) {
        [MusicHandler playReset];
       // stopWater = FALSE;
        bodyB->SetLinearVelocity(b2Vec2(0,0));
        bodyB->SetAngularVelocity(0);
        
        [self saveData];
        //[self performSelector:@selector(gotoHS) withObject:nil afterDelay:0.3];
        //ballBodyDef.position.y = 14.5f;
        float x = ball->GetPosition().x;
        // Previous bullets cleanup
        if (walls)
        {
            for (NSValue *wallPointer in walls)
            {
                b2Body *aWall = (b2Body*)[wallPointer pointerValue];
                CCNode *node = (CCNode*)aWall->GetUserData();
                [self removeChild:node cleanup:YES];
                world->DestroyBody(aWall);
            }
            [walls release];
            walls = nil;
        }
        [self setupLevels];
        
        ball->SetTransform(b2Vec2(x, 14.5f), 0);
    }
}

- (void)gotoHS {
    [[CCDirector sharedDirector] replaceScene:[GameOverScene node]];
}

- (void)updateScore {
    [scoreLabel setString:[NSString stringWithFormat:@"       Score: %i",score]];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:score forKey:@"score"];
    [defaults synchronize];
    
    
}
- (void)saveData {   
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:score forKey:@"newHS"];
//NSLog(@"saved high score");
    
    [defaults synchronize];
}
- (void)restoreData {
    // Get the stored data before the view loads
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults integerForKey:@"HS1"]) {
        highscore = [defaults integerForKey:@"HS1"];
        [highscoreLabel setString:[NSString stringWithFormat:@"HighScore: %i",highscore]];
    }
    
    
    if ([defaults boolForKey:@"IsMuted"]) {
        muted = [defaults boolForKey:@"IsMuted"];
        [[SimpleAudioEngine sharedEngine] setMute:muted];
    }
}

- (void)turnOnMusic {
    if ([[SimpleAudioEngine sharedEngine] mute]) {
        // This will unmute the sound
        muted = FALSE;
    }
    else {
        //This will mute the sound
        muted = TRUE;
    }
    [[SimpleAudioEngine sharedEngine] setMute:muted];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:muted forKey:@"IsMuted"];
    [defaults synchronize];
}


-(void)callEmitter {    
   // int xStrength = int(abs(bodyB->GetPosition().x - 8)) + 1;
   // int numParticle = 30 +CCRANDOM_0_1()*200 * xStrength;
    int numParticle = 30 +CCRANDOM_0_1()*100;
    myEmitter = [[CCParticleExplosion alloc] initWithTotalParticles:numParticle];
    //myEmitter.texture = [[CCTextureCache sharedTextureCache] addImage:@"goldstars1.png"];
    myEmitter.texture = [[CCTextureCache sharedTextureCache] addImage:@"goldstars1sm.png"];
    myEmitter.position = CGPointMake( mtp(ball->GetPosition().x) ,  mtp(ball->GetPosition().y));
    myEmitter.life =0.4f + CCRANDOM_0_1()*0.2;
    myEmitter.duration = 0.3f + CCRANDOM_0_1()*0.35;
    myEmitter.scale = 0.5f;
    //myEmitter.scale = 0.3 + CCRANDOM_0_1()*0.2 * xStrength;
    myEmitter.speed = 50.0f + CCRANDOM_0_1()*50.0f;
    //For not showing color
    myEmitter.blendAdditive = YES;
    [self addChild:myEmitter z:11];
    myEmitter.autoRemoveOnFinish = YES;
    
    //NSLog(@" Y values %0.0f Xstrength  %d Speed value: %0.0f  numparticles %d  myemtterspped %f myemitetrscale %0.0f", bodyB->GetPosition().y,xStrength,speed, numParticle, myEmitter.speed, myEmitter.scale);
}

-(void) draw
{
	// Default GL states: GL_TEXTURE_2D, GL_VERTEX_ARRAY, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
	// Needed states:  GL_VERTEX_ARRAY, 
	// Unneeded states: GL_TEXTURE_2D, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
	glDisable(GL_TEXTURE_2D);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	
	world->DrawDebugData();
	
	// restore default GL states
	glEnable(GL_TEXTURE_2D);
	glEnableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    
}


-(void) tick: (ccTime) dt
{
	//It is recommended that a fixed time step is used with Box2D for stability
	//of the simulation, however, we are using a variable time step here.
	//You need to make an informed choice, the following URL is useful
	//http://gafferongames.com/game-physics/fix-your-timestep/
	
	int32 velocityIterations = 8;
	int32 positionIterations = 1;
	
	// Instruct the world to perform a single step of simulation. It is
	// generally best to keep the time step and iterations fixed.
	world->Step(dt, velocityIterations, positionIterations);
    
	
	//Iterate over the bodies in the physics world
	for (b2Body* b = world->GetBodyList(); b; b = b->GetNext())
	{
		if (b->GetUserData() != NULL) {
			//Synchronize the AtlasSprites position and rotation with the corresponding body
			CCSprite *myActor = (CCSprite*)b->GetUserData();
			myActor.position = CGPointMake( b->GetPosition().x * PTM_RATIO, b->GetPosition().y * PTM_RATIO);
			myActor.rotation = -1 * CC_RADIANS_TO_DEGREES(b->GetAngle());
		}	
        //check if blinkie fell a level
        if (ball->GetPosition().y < 2.0){
            if(!level1) {
                level1 = TRUE;
                [self scored:550];
                //NSLog(@"Blinkie fell level1");
                //recreate the screen to "reset"
            }
        }
        else if (ball->GetPosition().y < 4.0) {
            if(!level2) {
                level2 = TRUE;
                [self scored:550];
                //NSLog(@"Blinkie fell level2");
            }        }
        else if (ball->GetPosition().y < 6.0) {
            if(!level3) {
                level3 = TRUE;
                [self scored:550];
                //NSLog(@"Blinkie fell level3");
            }        }
        else if (ball->GetPosition().y < 8.0) {
            if(!level4) {
                level4 = TRUE;
                [self scored:550];
                //NSLog(@"Blinkie fell level4");
            }        }
        else if (ball->GetPosition().y < 10.0) {
            if(!level5) {
                level5 = TRUE;
                [self scored:550];
                //NSLog(@"Blinkie fell level5");
            }        
        }
        else if (ball->GetPosition().y < 12.0) {
            if(!level6) {
                level6 = TRUE;
                [self scored:550];
                //NSLog(@"Blinkie fell level5");
            }        
        }
        
	}
    // Loop through all of the box2d bodies that are currently colliding, that we have
    // gathered with our custom contact listener...
    std::vector<MyContact>::iterator pos2;
    for(pos2 = contactListener->_contacts.begin(); pos2 != contactListener->_contacts.end(); ++pos2) {
        MyContact contact = *pos2;
        
        // Get the box2d bodies for each object
        b2Body *bodyA = contact.fixtureA->GetBody();
        b2Body *bodyB = contact.fixtureB->GetBody();
        if (bodyA->GetUserData() != NULL && bodyB->GetUserData() != NULL) {
            CCSprite *spriteA = (CCSprite *) bodyA->GetUserData();
            CCSprite *spriteB = (CCSprite *) bodyB->GetUserData();
            
            if (spriteA.tag == 88 && spriteB.tag == 11) {
                //NSLog(@"Game Ended");
                //[[CCDirector sharedDirector] replaceScene:[GameOverScene node]];
                [self restartGame:bodyA];
            }
            else if (spriteA.tag == 11 && spriteB.tag == 88) {
                //NSLog(@"Game Ended");
                //[[CCDirector sharedDirector] replaceScene:[GameOverScene node]];
                [self restartGame:bodyA];
            } else if (spriteA.tag == 99 && spriteB.tag == 11) {
                //NSLog(@"Game Ended");
                //[[CCDirector sharedDirector] replaceScene:[GameOverScene node]];
                [self endGame:bodyA];
            }
            else if (spriteA.tag == 11 && spriteB.tag == 99) {
                //NSLog(@"Game Ended");
                //[[CCDirector sharedDirector] replaceScene:[GameOverScene node]];
                [self endGame:bodyA];
            }
            
        }
        
        for (NSData *fixtureData in groundWalls)
        {
            b2Fixture *fixture;
            fixture = (b2Fixture*)[fixtureData pointerValue];
            
            if ((contact.fixtureA == _leftFixture   && contact.fixtureB == _ballFixture) ||
                (contact.fixtureA == _ballFixture && contact.fixtureB == _leftFixture  )) {
                // NSLog(@"Ball hit bottom!");
                    [self scored:-155];
            } else if ((contact.fixtureA == _rightFixture   && contact.fixtureB == _ballFixture) ||
                                   (contact.fixtureA == _ballFixture && contact.fixtureB == _rightFixture  )) {
                // NSLog(@"Ball hit bottom!");
                [self scored:-155];
            } 
        } 

        
    }
    
    
}

- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	//Add a new body/atlas sprite at the touched location
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		
		location = [[CCDirector sharedDirector] convertToGL: location];
		
		//[self addNewSpriteWithCoords: location];
	}
}
- (void)accelerometer:(UIAccelerometer*)accelerometer didAccelerate:(UIAcceleration*)acceleration
{	
	static float prevX=0, prevY=0;
	
	//#define kFilterFactor 0.05f
#define kFilterFactor 1.0f	// don't use filter. the code is here just as an example
	
	float accelX = (float) acceleration.x * kFilterFactor + (1- kFilterFactor)*prevX;
	float accelY = (float) acceleration.y * kFilterFactor + (1- kFilterFactor)*prevY;
	
	prevX = accelX;
	prevY = accelY;
    
    int accXFactor = 10;
    int accYFactor = 10;
    
    if (score != 0 && score > 500 && score < 50000) {
        accYFactor = score/100;
        accXFactor = score/100;
    }
    
	b2Vec2 gravity(accelX * accXFactor * CC_CONTENT_SCALE_FACTOR(), accelY * accYFactor * CC_CONTENT_SCALE_FACTOR());
    
	world->SetGravity( gravity );
}

// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
    [myEmitter release];
    
    //IF you have particular spritesheets to be removed! Don't use these if you haven't any
    //[[CCSpriteFrameCache sharedSpriteFrameCache]removeSpriteFramesFromFile:@"froggie.plist"];
    [[CCSpriteFrameCache sharedSpriteFrameCache]removeSpriteFramesFromFile:@"bally.plist"];
    
    //Use these
    [[CCSpriteFrameCache sharedSpriteFrameCache] removeSpriteFrames];
    [[CCSpriteFrameCache sharedSpriteFrameCache] removeUnusedSpriteFrames];
    
    
    //Use these
    [[CCTextureCache sharedTextureCache] removeUnusedTextures];
    [[CCTextureCache sharedTextureCache] removeAllTextures];
    [[CCDirector sharedDirector] purgeCachedData];
    
    //Try out and use it. Not compulsory
    [self removeAllChildrenWithCleanup: YES];
    
	// in case you have something to dealloc, do it in this method
	delete world;
	world = NULL;
	
	delete m_debugDraw;
    
    [groundWalls release];
    [walls release];
        
    //[pause release];
    //[sprite release];

    
    
	// don't forget to call "super dealloc"
	[super dealloc];
}
@end
