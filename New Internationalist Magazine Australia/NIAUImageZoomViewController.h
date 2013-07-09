//
//  NIAUImageZoomViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 9/07/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NIAUImageZoomViewController : UIViewController <UIGestureRecognizerDelegate, UIScrollViewDelegate>

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;

@property (nonatomic, strong) UIImage *imageToLoad;

@property (nonatomic, strong) IBOutlet UIImageView *image;

@end
