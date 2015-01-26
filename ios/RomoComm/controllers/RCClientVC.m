//
//  RCClientVC.m
//  RomoComm
//
//  Created by Dominick Lim on 11/25/13.
//  Copyright (c) 2013 Dominick Lim. All rights reserved.
//

#import "RCClientVC.h"
#import "RCClientView.h"

#import "RCWebSocket.h"
#import <RMCore/RMCore.h>

#import "RCAppDelegate.h"

@interface RCClientVC () <RCWebSocketDelegate>

@property (nonatomic, strong) RCClientView *view;

@property (nonatomic, strong) RCWebSocket *webSocket;
@property (nonatomic, strong) RMCoreRobot<DifferentialDriveProtocol> *robot;
@property (nonatomic, strong) UITapGestureRecognizer *tripleTapRecognizer;
@property (nonatomic, strong) NSTimer *sendNextTimer;

- (void)startSendNextTimer;

- (void)applicationWillEnterForeground:(UIApplication *)application;
- (void)applicationWillResignActive:(UIApplication *)application;

- (void)handleTripleTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer;

- (void)didReceiveInitialEvent:(NSDictionary *)args;
- (void)didReceiveFreedEvent;
- (void)didReceivePartneredEvent:(NSDictionary *)args;
- (void)didReceiveEmptyEvent;

- (void)didReceiveCommand:(NSDictionary *)args;
- (void)didReceiveDirectionalPadCommand:(NSString *)direction;
- (void)didReceiveTurnToHeadingCommand:(NSDictionary *)data;
- (void)didReceiveDriveForwardForSecondsCommand:(NSDictionary *)data;
- (void)didReceiveDriveBackwardForSecondsCommand:(NSDictionary *)data;

- (void)sendNextEvent;

@end

static NSTimeInterval const kSendNextPeriod = 1.0;

static NSString *const kIdentificationRole = @"robot";
static NSString *const kIdentificationKey = @"automationlab";

@implementation RCClientVC

#pragma mark -- Object lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:[UIApplication sharedApplication]];

        [self.view addGestureRecognizer:self.tripleTapRecognizer];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark -- View lifecycle

- (void)loadView
{
    self.view = [[RCClientView alloc] initWithFrame:[UIScreen mainScreen].bounds];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.webSocket = [[RCWebSocket alloc] init];
    self.webSocket.delegate = self;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.webSocket disconnect];
}

#pragma mark -- Private properties

- (RMCoreRobot<DifferentialDriveProtocol> *)robot
{
    return (RMCoreRobot<DifferentialDriveProtocol> *)((RCAppDelegate *)[UIApplication sharedApplication].delegate).robot;
}

- (UITapGestureRecognizer *)tripleTapRecognizer
{
    if (!_tripleTapRecognizer) {
        _tripleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                       action:@selector(handleTripleTapGesture:)];
        _tripleTapRecognizer.numberOfTapsRequired = 3;
    }
    
    return _tripleTapRecognizer;
}

#pragma mark -- Private methods

- (void)startSendNextTimer
{
    if (self.sendNextTimer == nil || ![self.sendNextTimer isValid]) {
        self.sendNextTimer = [NSTimer timerWithTimeInterval:kSendNextPeriod
                                                     target:self
                                                   selector:@selector(sendNextEvent)
                                                   userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.sendNextTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopSendNextTimer
{
    [self.sendNextTimer invalidate];
    self.sendNextTimer = nil;
}

#pragma mark -- Notification handlers

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self.webSocket restart];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [self.webSocket disconnect];
}

#pragma mark -- UI events

- (void)handleTripleTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer
{
    [self.webSocket restart];
}

#pragma mark -- Socket event handling

- (void)didReceiveInitialEvent:(NSDictionary *)args
{
    [self.webSocket sendEvent:@"identification" withData:@{@"role": kIdentificationRole,
                                                           @"key": kIdentificationKey}];
}

- (void)didReceiveFreedEvent
{
    self.view.backgroundColor = [UIColor blueColor];

    [self startSendNextTimer];
}

- (void)didReceivePartneredEvent:(NSDictionary *)args
{
    self.view.backgroundColor = [UIColor magentaColor];

    [self.sendNextTimer invalidate];
    self.sendNextTimer = nil;
}

- (void)didReceiveEmptyEvent
{
    
}

- (void)didReceiveCommand:(NSDictionary *)args
{
    NSString *name = args[@"name"];
    NSDictionary *data = args[@"data"];

    if ([name isEqualToString:@"dpad"]) {
        [self didReceiveDirectionalPadCommand:data[@"direction"]];
    } else if ([name isEqualToString:@"start/turn"]) {
        [self didReceiveTurnCommand:data];
    } else if ([name isEqualToString:@"start/turnToHeading"]) {
        [self didReceiveTurnToHeadingCommand:data];
    } else if ([name isEqualToString:@"start/driveForward"]) {
        [self didReceiveDriveForwardCommand:data];
    } else if ([name isEqualToString:@"start/driveForwardForSeconds"]) {
        [self didReceiveDriveForwardForSecondsCommand:data];
    } else if ([name isEqualToString:@"start/driveBackward"]) {
        [self didReceiveDriveBackwardCommand:data];
    } else if ([name isEqualToString:@"start/driveBackwardForSeconds"]) {
        [self didReceiveDriveBackwardForSecondsCommand:data];
    } else if ([name isEqualToString:@"stop"]) {
        [self didReceiveStopCommand:data];
    }
}

- (void)didReceiveDirectionalPadCommand:(NSString *)direction {
    NSString *directionLetter = @"";
    
    if (direction && direction.length > 0) {
        directionLetter = [[direction substringToIndex:1] uppercaseString];
    }
    
    if ([direction isEqualToString:@"left"]) {
        self.view.backgroundColor = [UIColor yellowColor];
        [self.robot driveWithLeftMotorPower:-0.75 rightMotorPower:0.75];
    } else if ([direction isEqualToString:@"up"]) {
        self.view.backgroundColor = [UIColor redColor];
        [self.robot driveWithLeftMotorPower:0.5 rightMotorPower:0.5];
    } else if ([direction isEqualToString:@"right"]) {
        self.view.backgroundColor = [UIColor greenColor];
        [self.robot driveWithLeftMotorPower:0.75 rightMotorPower:-0.75];
    } else if ([direction isEqualToString:@"down"]) {
        self.view.backgroundColor = [UIColor purpleColor];
        [self.robot driveWithLeftMotorPower:-0.5 rightMotorPower:-0.5];
    } else {
        self.view.backgroundColor = [UIColor magentaColor];
        directionLetter = @"";
        [self.robot driveWithLeftMotorPower:0.0 rightMotorPower:0.0];
    }
    
    self.view.directionLabel.text = directionLetter;
}

- (void)didReceiveTurnCommand:(NSDictionary *)data {
    self.view.backgroundColor = [UIColor blueColor];
    // direction: 1 = CW, -1 = CCW
    int direction = data[@"direction"] ? [data[@"direction"] intValue] : 1;
    int power = data[@"power"] ? [data[@"power"] intValue] : 0.75;

    if (self.robot) {
        [self.robot driveWithLeftMotorPower:direction * power rightMotorPower:-direction * power];
    }
}

- (void)didReceiveTurnToHeadingCommand:(NSDictionary *)data {
    float heading = data[@"heading"] ? [data[@"heading"] floatValue] : 0;
    float radius = data[@"radius"] ? [data[@"radius"] floatValue] : 0;
    float turnTimeout = 3;

    if (self.robot) {
        [self.robot turnByAngle:heading withRadius:radius
                  finishingAction:RMCoreTurnFinishingActionStopDriving
                       completion:^(BOOL success, float heading) {
                           [self.webSocket sendCommand:@"finish/turnToHeading"
                                              withData:@{@"heading": @(heading)}];
                       }];

        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(turnTimeout * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.robot stopAllMotion];
            [self.webSocket sendCommand:@"finish/turnToHeading"
                               withData:@{@"heading": @(heading)}];
        });
    } else {
        [self.webSocket sendCommand:@"finish/turnToHeading"
                           withData:@{@"heading": @(heading)}];
    }
}

- (void)didReceiveDriveForwardCommand:(NSDictionary *)data {
    self.view.backgroundColor = [UIColor greenColor];
    float speed = data[@"speed"] ? [data[@"speed"] floatValue] : 1.0;
    
    [self.webSocket sendCommand:@"finish/driveForward" withData:@{}];

    if (self.robot) {
        [self.robot driveForwardWithSpeed:speed];
    } else {
        [self.webSocket sendCommand:@"finish/driveForward" withData:@{}];
    }
}

- (void)didReceiveDriveForwardForSecondsCommand:(NSDictionary *)data {
    float seconds = data[@"seconds"] ? [data[@"seconds"] floatValue] : 0;
    float speed = data[@"speed"] ? [data[@"speed"] floatValue] : 1.0;
    
    if (self.robot) {
        if (seconds > 0) {
            [self.robot driveForwardWithSpeed:speed];
        } else {
            [self.robot driveBackwardWithSpeed:speed];
            seconds *= -1;
        }
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.robot stopAllMotion];
            [self.webSocket sendCommand:@"finish/driveForwardForSeconds" withData:@{}];
        });
    } else {
        [self.webSocket sendCommand:@"finish/driveForwardForSeconds" withData:@{}];
    }
}

- (void)didReceiveDriveBackwardCommand:(NSDictionary *)data {
    float speed = data[@"speed"] ? [data[@"speed"] floatValue] : 1.0;

    if (self.robot) {
        [self.robot driveBackwardWithSpeed:speed];
    } else {
        [self.webSocket sendCommand:@"finish/driveBackward" withData:@{}];
    }
}

- (void)didReceiveDriveBackwardForSecondsCommand:(NSDictionary *)data {
    float seconds = data[@"seconds"] ? [data[@"seconds"] floatValue] : 0;
    
    if (self.robot) {
        if (seconds > 0) {
            [self.robot driveBackwardWithSpeed:1.0];
        } else {
            [self.robot driveForwardWithSpeed:1.0];
            seconds *= -1;
        }
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.robot stopAllMotion];
            [self.webSocket sendCommand:@"finish/driveBackwardForSeconds" withData:@{}];
        });
    } else {
        [self.webSocket sendCommand:@"finish/driveBackwardForSeconds" withData:@{}];
    }
}

- (void)didReceiveStopCommand:(NSDictionary *)data {
    self.view.backgroundColor = [UIColor redColor];
    [self.robot stopAllMotion];
}

#pragma mark -- RCWebSocket convenience methods

- (void)sendNextEvent
{
    [self.webSocket sendEvent:@"next" withData:@{}];
}

#pragma mark -- RCWebSocketDelegate methods

- (void)webSocket:(SRWebSocket *)webSocket didReceiveEvent:(NSString *)event withArgs:(NSDictionary *)args
{
    if ([event isEqualToString:@"initial"]) {
        [self didReceiveInitialEvent:args];
    } else if ([event isEqualToString:@"partnered"]) {
        [self didReceivePartneredEvent:args];
    } else if ([event isEqualToString:@"freed"]) {
        [self didReceiveFreedEvent];
    } else if ([event isEqualToString:@"empty"]) {
        [self didReceiveEmptyEvent];
    } else if ([event isEqualToString:@"receivedCommand"]) {
        [self didReceiveCommand:args];
    }
}

- (void)webSocketWillDisconnect:(RCWebSocket *)webSocket
{
    [self stopSendNextTimer];
    self.view.backgroundColor = [UIColor blackColor];
}

- (void)webSocket:(RCWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [self stopSendNextTimer];
    self.view.backgroundColor = [UIColor blackColor];
}

@end
