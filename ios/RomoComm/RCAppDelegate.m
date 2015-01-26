//
//  RCAppDelegate.m
//  RomoComm
//
//  Created by Dominick Lim on 11/25/13.
//  Copyright (c) 2013 Dominick Lim. All rights reserved.
//

#import "RCAppDelegate.h"
#import "RCClientVC.h"
#import <RMCore/RMCore.h>

@interface RCAppDelegate ()<RMCoreDelegate>

@property (nonatomic, strong, readwrite) RMCoreRobot *robot;
@property (nonatomic, strong) RCClientVC *socketVC;

@end

@implementation RCAppDelegate

#pragma mark -- Private properties

- (RCClientVC *)socketVC
{
    if (!_socketVC) {
        _socketVC = [[RCClientVC alloc] init];
    }
    
    return _socketVC;
}


#pragma mark -- UIApplication delegate methods

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:self.socketVC];
    [navigationController setNavigationBarHidden:YES animated:NO];
    
    self.window.rootViewController = navigationController;

    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    [RMCore setDelegate:self];

    return YES;
}

#pragma mark -- RMCoreDelegate Methods

- (void)robotDidConnect:(RMCoreRobot *)robot
{
    self.window.rootViewController.view.backgroundColor = [UIColor brownColor];

    if ([robot isDrivable]) {
        self.robot = robot;
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (robot == self.robot) {
        self.robot = nil;
    }
}

@end
