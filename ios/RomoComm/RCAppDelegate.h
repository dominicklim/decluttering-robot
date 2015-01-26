//
//  RCAppDelegate.h
//  RomoComm
//
//  Created by Dominick Lim on 11/25/13.
//  Copyright (c) 2013 Dominick Lim. All rights reserved.
//

#import <UIKit/UIKit.h>
@class RMCoreRobot;

@interface RCAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong, readonly) RMCoreRobot *robot;

@end
