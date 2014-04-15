//
//  NIAUHelper.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 26/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import "NIAUHelper.h"

@implementation NIAUHelper

NSString *kAlertTitle = @"Did you know?";

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

+ (void)roundedCornersWithRadius:(float)radius inImageView:(UIImageView *)imageView
{
    // Rounded corners for any imageView
    imageView.layer.masksToBounds = YES;
    imageView.layer.cornerRadius = radius;
}

+ (void)addShadowToImageView:(UIImageView *)imageView withRadius:(float)radius andOffset:(CGSize)size andOpacity:(float)opacity
{
    // Shadow for any imageView
    imageView.layer.shadowColor = [UIColor blackColor].CGColor;
    imageView.layer.shadowOffset = size;
    imageView.layer.shadowOpacity = opacity;
    imageView.layer.shadowRadius = radius;
    imageView.clipsToBounds = NO;
}

+ (UIImage *)imageWithRoundedCornersSize:(float)cornerRadius usingImage:(UIImage *)original
{
    if (original) {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:original];
        
        // Begin a new image that will be the new image with the rounded corners
        // (here with the size of an UIImageView)
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, NO, 1.0);
        
        // Add a clip before drawing anything, in the shape of an rounded rect
        [[UIBezierPath bezierPathWithRoundedRect:imageView.bounds
                                    cornerRadius:cornerRadius] addClip];
        // Draw your image
        [original drawInRect:imageView.bounds];
        
        // Get the image, here setting the UIImageView image
        imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        
        // Lets forget about that we were drawing
        UIGraphicsEndImageContext();
        
        return imageView.image;
    } else {
        return nil;
    }
}

+ (void)showHelpAlertWithMessage:(NSString *)message andDelegate:(NSObject *)delegate
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:kAlertTitle message:message delegate:delegate cancelButtonTitle:@"Don't show again" otherButtonTitles:@"Thanks!", nil];
    [alert show];
}

+ (NSString *)helpAlertTitle
{
    return kAlertTitle;
}

#pragma mark - Force Crash for Crashlytics

+ (void)forceCrash
{
    NSArray *emptyArray = @[];
    NSLog(@"Making a crash: %@",[emptyArray objectAtIndex:1]);
}


@end
