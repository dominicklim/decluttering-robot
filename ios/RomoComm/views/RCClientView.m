//
//  RCClientView.m
//  RomoComm
//
//  Created by Dominick Lim on 12/13/13.
//  Copyright (c) 2013 Dominick Lim. All rights reserved.
//

#import "RCClientView.h"

@interface RCClientView ()

@property (nonatomic, strong, readwrite) UILabel *directionLabel;

@end

@implementation RCClientView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.directionLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.directionLabel.frame = (CGRect){CGPointZero, self.frame.size};
    self.directionLabel.center = self.center;
}

#pragma mark -- Private properties

- (UILabel *)directionLabel
{
    if (!_directionLabel) {
        _directionLabel = [[UILabel alloc] init];
        _directionLabel.font = [UIFont boldSystemFontOfSize:10 * [UIFont systemFontSize]];
        _directionLabel.textColor = [UIColor whiteColor];
        _directionLabel.textAlignment = NSTextAlignmentCenter;
        _directionLabel.shadowColor = [UIColor blackColor];
        _directionLabel.layer.shadowColor = [[UIColor blackColor] CGColor];
        _directionLabel.layer.shadowOffset = CGSizeMake(0.0f, 10.0f);
        _directionLabel.layer.shadowOpacity = 1.0f;
        _directionLabel.layer.shadowRadius = 10.0f;
    }

    return _directionLabel;
}

@end
