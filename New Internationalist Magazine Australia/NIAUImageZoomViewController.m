//
//  NIAUImageZoomViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 9/07/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUImageZoomViewController.h"

#define ZOOM_STEP 1.5
#define animationSpeed 0.3

@interface NIAUImageZoomViewController ()

@end

@implementation NIAUImageZoomViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.image.image = self.imageToLoad;
    
    // add gesture recognizers to the image view
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    
    [doubleTap setNumberOfTapsRequired:2];
    
    [self.image addGestureRecognizer:singleTap];
    [self.image addGestureRecognizer:doubleTap];
    
    [singleTap requireGestureRecognizerToFail:doubleTap];
    
    float minimumScale = [self.scrollView frame].size.width  / [self.image frame].size.width;
    [self.scrollView setMinimumZoomScale:minimumScale];
    [self.scrollView setZoomScale:minimumScale];
    
    [self.scrollView setBackgroundColor:[UIColor blackColor]];
    
    [self.image setCenter:CGPointMake(self.scrollView.center.x, self.scrollView.center.y - (self.navigationController.navigationBar.frame.size.height / 2))];
    self.image.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self sendGoogleAnalyticsStats];
}

- (void)sendGoogleAnalyticsStats
{
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:@"Image zoom"];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createAppView] build]];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.image;
}

#pragma mark -
#pragma mark Responding to gestures

- (void)handleSingleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    NSLog(@"Single tap detected.");
    
    // Tap once to show/hide navigation
    if (!self.navigationController.navigationBarHidden) {
//        NSLog(@"Tapped to hide");
        [[self navigationController] setNavigationBarHidden:YES animated:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
        [UIView animateWithDuration:animationSpeed animations:^{
//            [self.scrollView setBackgroundColor:[UIColor blackColor]];
            float minimumScale = [self.scrollView frame].size.width  / [self.image frame].size.width;
            [self.scrollView setZoomScale:minimumScale];
        } completion:NULL];
    } else {
//        NSLog(@"Tapped to show");
        [[self navigationController] setNavigationBarHidden:NO animated:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
        [UIView animateWithDuration:animationSpeed animations:^{
//            [self.scrollView setBackgroundColor:[UIColor whiteColor]];
            float minimumScale = [self.scrollView frame].size.width  / [self.image frame].size.width;
            [self.scrollView setZoomScale:minimumScale];
        } completion:NULL];
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    // double tap zooms in
    NSLog(@"Double-tap detected.");
    float newScale = [self.scrollView zoomScale] * ZOOM_STEP;
    CGRect zoomRect = [self zoomRectForScale:newScale withCenter:[gestureRecognizer locationInView:gestureRecognizer.view]];
    [self.scrollView zoomToRect:zoomRect animated:YES];
}

#pragma mark -
#pragma mark Utility methods

- (CGRect)zoomRectForScale:(float)scale withCenter:(CGPoint)center {
    
    CGRect zoomRect;
    
    // the zoom rect is in the content view's coordinates.
    //    At a zoom scale of 1.0, it would be the size of the imageScrollView's bounds.
    //    As the zoom scale decreases, so more content is visible, the size of the rect grows.
    zoomRect.size.height = [self.scrollView frame].size.height / scale;
    zoomRect.size.width  = [self.scrollView frame].size.width  / scale;
    
    // choose an origin so as to get the right center.
    zoomRect.origin.x    = center.x - (zoomRect.size.width  / 2.0);
    zoomRect.origin.y    = center.y - (zoomRect.size.height / 2.0);
    
    return zoomRect;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
