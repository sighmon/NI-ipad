//
//  NIAUHelper.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 26/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NIAUHelper : NSObject

+ (void)drawGradientInView:(UIView *)view;
+ (void)roundedCornersWithRadius:(float)radius inImageView:(UIImageView *)imageView;
+ (void)addShadowToImageView:(UIImageView *)imageView withRadius:(float)radius andOffset:(CGSize)size andOpacity:(float)opacity;
+ (UIImage *)imageWithRoundedCornersSize:(float)cornerRadius usingImage:(UIImage *)original;
+ (void)showHelpAlertWithMessage:(NSString *)message andDelegate:(NSObject *)delegate;
+ (NSString *)helpAlertTitle;
+ (void)fadeInImage:(UIImage *)image intoImageView:(UIImageView *)imageView;

+ (CGSize)screenSize;

+ (void)forceCrash;

+ (NSString *)fontSizePercentage;

+ (BOOL)validIssueInURL:(NSURL *)url;
+ (BOOL)validArticleInURL:(NSURL *)url;
+ (BOOL)validCategoryInURL:(NSURL *)url;
+ (BOOL)validCategoriesInURL:(NSURL *)url;

@end
