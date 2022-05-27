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

+ (void)fadeInImage:(UIImage *)image intoImageView:(UIImageView *)imageView
{
    // Note: this is for fading images once they load, say for UITableViews
    [imageView setAlpha:0.0];
    [imageView setImage:image];
    //    [articleImage.constraints[0] setConstant:57.];
    //    [cell setSeparatorInset:UIEdgeInsetsMake(0, 58., 0, 0)];
    //    [cell setNeedsLayout];
    [UIView animateWithDuration:0.3 animations:^{
        [imageView setAlpha:1.0];
    }];
}

+ (CGSize)screenSize
{
    return [[UIScreen mainScreen] bounds].size;
}

#pragma mark - Force Crash for Crashlytics

+ (void)forceCrash
{
    NSArray *emptyArray = @[];
    NSLog(@"Making a crash: %@",[emptyArray objectAtIndex:1]);
}

#pragma mark - Dynamic Text Font Size

+ (NSString *)fontSizePercentage
{
    // Set dynamic font size adjustment from phone setting
    
    NSString *fontSize = @"100%";
	NSString *userContentSize = [[UIApplication sharedApplication] preferredContentSizeCategory];
    
	if ([userContentSize isEqualToString:UIContentSizeCategoryExtraSmall]) {
		fontSize = @"70%";
        
	} else if ([userContentSize isEqualToString:UIContentSizeCategorySmall]) {
		fontSize = @"80%";
        
	} else if ([userContentSize isEqualToString:UIContentSizeCategoryMedium]) {
		fontSize = @"90%";
        
	} else if ([userContentSize isEqualToString:UIContentSizeCategoryLarge]) {
		fontSize = @"100%";
        
	} else if ([userContentSize isEqualToString:UIContentSizeCategoryExtraLarge]) {
		fontSize = @"110%";
        
	} else if ([userContentSize isEqualToString:UIContentSizeCategoryExtraExtraLarge]) {
		fontSize = @"120%";
        
	} else if ([userContentSize isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge]) {
		fontSize = @"130%";
        
    } else if ([userContentSize isEqualToString:UIContentSizeCategoryAccessibilityMedium]) {
        fontSize = @"150%";
        
    } else if ([userContentSize isEqualToString:UIContentSizeCategoryAccessibilityLarge]) {
        fontSize = @"170%";
        
    } else if ([userContentSize isEqualToString:UIContentSizeCategoryAccessibilityExtraLarge]) {
        fontSize = @"190%";
        
    } else if ([userContentSize isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraLarge]) {
        fontSize = @"210%";
        
    } else if ([userContentSize isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
        fontSize = @"230%";
        
    }
    
    return fontSize;
}

+ (UIFont *)scaleFont:(NSString *)fontTextStyle withScale:(float)scale andiPadSizeCompensation: (BOOL)iPadSizeCompensation
{
    UIFont *currentDynamicFontSize = [UIFont preferredFontForTextStyle:fontTextStyle];
    if (iPadSizeCompensation && IS_IPAD()) {
        return [currentDynamicFontSize fontWithSize:currentDynamicFontSize.pointSize*scale];
    } else {
        return [currentDynamicFontSize fontWithSize:currentDynamicFontSize.pointSize*scale*.8];
    }
}

+ (BOOL)validArticleInURL:(NSURL *)url
{
    NSError *error = NULL;
    NSRegularExpression *articleURLRegex = [NSRegularExpression regularExpressionWithPattern:@"(issues)\\/(\\d+)\\/(articles)\\/(\\d+)"
                                                                                     options:NSRegularExpressionCaseInsensitive
                                                                                       error:&error];
    
    NSUInteger articleURLMatches = [articleURLRegex numberOfMatchesInString:[url absoluteString]
                                                                    options:0
                                                                      range:NSMakeRange(0, [[url absoluteString] length])];
    
    if ((articleURLMatches > 0) && !error) {
        // URL looks like it's an article
        return true;
    } else {
        return false;
    }
}

+ (BOOL)validIssueInURL:(NSURL *)url
{
    NSError *error = NULL;
    
    NSRegularExpression *issueURLRegex = [NSRegularExpression regularExpressionWithPattern:@"(issues)\\/(\\d+)"
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:&error];
    
    NSUInteger issueURLMatches = [issueURLRegex numberOfMatchesInString:[url absoluteString]
                                                                options:0
                                                                  range:NSMakeRange(0, [[url absoluteString] length])];
    
    if ((issueURLMatches > 0) && !error) {
        // URL looks like it's an issue url
        return true;
    } else {
        return false;
    }
}

+ (BOOL)validCategoryInURL:(NSURL *)url
{
    NSError *error = NULL;
    
    NSRegularExpression *categoryURLRegex = [NSRegularExpression regularExpressionWithPattern:@"(categories)\\/(\\d+)"
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:&error];
    
    NSUInteger categoryURLMatches = [categoryURLRegex numberOfMatchesInString:[url absoluteString]
                                                                options:0
                                                                  range:NSMakeRange(0, [[url absoluteString] length])];
    
    if ((categoryURLMatches > 0) && !error) {
        // URL looks like it's a category url
        return true;
    } else {
        return false;
    }
}

+ (BOOL)validCategoriesInURL:(NSURL *)url
{
    NSError *error = NULL;
    
    NSRegularExpression *categoriesURLRegex = [NSRegularExpression regularExpressionWithPattern:@"(categories)"
                                                                                      options:NSRegularExpressionCaseInsensitive
                                                                                        error:&error];
    
    NSUInteger categoriesURLMatches = [categoriesURLRegex numberOfMatchesInString:[url absoluteString]
                                                                      options:0
                                                                        range:NSMakeRange(0, [[url absoluteString] length])];
    
    if ((categoriesURLMatches > 0) && !error) {
        // URL looks like it's a category url
        return true;
    } else {
        return false;
    }
}

+ (NSString *)URLEncodedString:(NSString *)string
{
    if (string && string.length > 0) {
        return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                     NULL,
                                                                                     (CFStringRef)string,
                                                                                     NULL,
                                                                                     (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                     kCFStringEncodingUTF8 ));
    } else {
        return @"";
    }
}

+ (NSString *)stringByStrippingHTML:(NSString *)string {
  NSRange range;
  while ((range = [string rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
      string = [string stringByReplacingCharactersInRange:range withString:@""];
  return string;
}

+ (void)updateSharedUserDefaults
{
    NSUserDefaults *groupUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.au.com.newint.New-Internationalist-Magazine-Australia"];
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [groupUserDefaults setBool:[standardUserDefaults boolForKey:@"showHelp"] forKey:@"showHelp"];
    [groupUserDefaults setBool:[standardUserDefaults boolForKey:@"googleAnalytics"] forKey:@"googleAnalytics"];
    [groupUserDefaults setBool:[standardUserDefaults boolForKey:@"bigImages"] forKey:@"bigImages"];
    [groupUserDefaults synchronize];
}

@end
