//
//  NIAUImageZoomViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 9/07/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUIssue.h"

#import "GAI.h"
#import "GAITracker.h"
#import "GAITrackedViewController.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "GAILogger.h"

@interface NIAUImageZoomViewController : UIViewController <UIGestureRecognizerDelegate, UIScrollViewDelegate>

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;

@property (nonatomic, strong) UIImage *imageToLoad;
@property (nonatomic, strong) NIAUArticle *articleOfOrigin;
@property (nonatomic, strong) NIAUIssue *issueOfOrigin;

@property (nonatomic, weak) IBOutlet UIImageView *image;

@property (weak, nonatomic) IBOutlet UINavigationItem *shareAction;

@end
