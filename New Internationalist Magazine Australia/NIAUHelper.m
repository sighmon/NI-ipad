//
//  NIAUHelper.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 26/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import "NIAUHelper.h"

@implementation NIAUHelper

+ (void)drawGradientInView:(UIView *)view
{
    for (__strong CALayer *layer in [view.layer sublayers]) {
        if ([[layer name] isEqualToString: @"backgroundGradient"] == YES) {
            [layer removeFromSuperlayer];
            break;
        }
    }
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y, view.frame.size.width*2, view.frame.size.height);
    
    // NI Greens
//    UIColor *startColour = [UIColor colorWithHue:0.2111 saturation:0.87 brightness:0.61 alpha:1.0];
//    UIColor *endColour = [UIColor colorWithHue:0.2111 saturation:0.90 brightness:0.25 alpha:1.0];
    
    // Greys
    UIColor *startColour = [UIColor colorWithRed:110/255. green:119/255. blue:128/255. alpha:1.0];
    UIColor *endColour = [UIColor colorWithRed:61/255. green:66/255. blue:72/255. alpha:1.0];
    
    gradient.colors = @[(id)[startColour CGColor], (id)[endColour CGColor]];
    gradient.name = @"backgroundGradient";
    [view.layer insertSublayer:gradient atIndex:0];
}

@end
