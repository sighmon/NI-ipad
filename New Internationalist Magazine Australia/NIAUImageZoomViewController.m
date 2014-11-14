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
    
    float minimumScale = [self.scrollView frame].size.width  / self.image.image.size.width; //[self.image frame].size.width;
    [self.scrollView setBackgroundColor:[UIColor whiteColor]];
    self.scrollView.contentSize = self.image.image.size;
    self.scrollView.delegate = self;
    [self.scrollView setMinimumZoomScale:minimumScale];
    [self.scrollView setMaximumZoomScale:6.0];
    [self.scrollView setZoomScale:minimumScale];
    
    [self sendGoogleAnalyticsStats];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self animateMinimumZoomScaleWithScale:[self calculateScale]];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    // Avoiding crash where user manages to tap to an article before the screen has finished scrolling
    [self.scrollView setDelegate:nil];
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
    DebugLog(@"Single tap detected.");
    
    // Tap once to show/hide navigation
    if (!self.navigationController.navigationBarHidden) {
//        DebugLog(@"Tapped to hide");
        [[self navigationController] setNavigationBarHidden:YES animated:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
        [UIView animateWithDuration:animationSpeed animations:^{
            [self.scrollView setBackgroundColor:[UIColor blackColor]];
            // Note: use [self calculateFullScreenScale] if we want images edge to edge
            [self.scrollView setZoomScale:[self calculateScale]];
            [self centerContent];
        } completion:NULL];
    } else {
//        DebugLog(@"Tapped to show");
        [[self navigationController] setNavigationBarHidden:NO animated:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
        [UIView animateWithDuration:animationSpeed animations:^{
            [self.scrollView setBackgroundColor:[UIColor whiteColor]];
            [self.scrollView setZoomScale:[self calculateScale]];
            [self centerContent];
        } completion:NULL];
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    // double tap zooms in
    DebugLog(@"Double-tap detected.");
    float newScale = [self.scrollView zoomScale] * ZOOM_STEP;
    CGRect zoomRect = [self zoomRectForScale:newScale withCenter:[gestureRecognizer locationInView:gestureRecognizer.view]];
    [self.scrollView zoomToRect:zoomRect animated:YES];
}

#pragma mark -
#pragma mark Social sharing

- (IBAction)shareActionTapped:(id)sender
{
    NSString *origin;
    NSMutableArray *itemsToShare = [[NSMutableArray alloc] init];
   
    if (self.image.image) {
        [itemsToShare addObject:self.image.image];
    }
    
    if (self.issueOfOrigin) {
        origin = [NSString stringWithFormat:@"I found this image in New Internationalist Magazine '%@'.", self.issueOfOrigin.title];
        [itemsToShare addObject:origin];
        [itemsToShare addObject:self.issueOfOrigin.getWebURL];
    } else if (self.articleOfOrigin) {
        origin = [NSString stringWithFormat:@"I found this image in a New Internationalist article '%@'.", self.articleOfOrigin.title];
        [itemsToShare addObject:origin];
        [itemsToShare addObject:self.articleOfOrigin.getGuestPassURL];
    } else {
        origin = @"I found this image in New Internationalist Magazine.";
        [itemsToShare addObject:origin];
    }
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [activityController setValue:[NSString stringWithFormat:@"Image from New Internationalist magazine."] forKey:@"subject"];
    [[UINavigationBar appearance] setTintColor:self.view.tintColor];
    
    // Avoid the iOS 8 iPad crash
    if (IS_IPAD() && SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        activityController.popoverPresentationController.barButtonItem = sender;
    };
    
    [self presentViewController:activityController animated:YES completion:nil];
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

- (float)calculateScale
{
    if ([self isViewRatioGreaterThanImageRatio]) {
        return [self.scrollView frame].size.height / self.image.image.size.height;
    } else {
        return [self.scrollView frame].size.width  / self.image.image.size.width;
    }
}

- (float)calculateFullScreenScale
{
    if ([self isViewRatioGreaterThanImageRatio]) {
        return [self.scrollView frame].size.width / self.image.image.size.width;
    } else {
        return [self.scrollView frame].size.height / self.image.image.size.height;
    }
}

- (BOOL)isViewRatioGreaterThanImageRatio
{
    float viewRatio = self.view.frame.size.width / self.view.frame.size.height;
    float imageRatio = self.image.image.size.width / self.image.image.size.height;
    if (viewRatio > imageRatio) {
        return YES;
    } else {
        return NO;
    }
}

- (void)centerContent
{
    // From https://github.com/steipete/PSTCenteredScrollView
    
    CGFloat top = 0, left = 0; //topOffset = 0;
    
//    if (self.navigationController.navigationBarHidden) {
//        topOffset = 0.;
//    } else {
//        if (UIInterfaceOrientationIsPortrait([[UIDevice currentDevice] orientation])) {
//            topOffset = 64.;
//        } else {
//            topOffset = 52.;
//        }
//    }
    
    // TODO: topOffset not used yet.. trying to center taking into account Navigation bar height
    
    if (self.image.frame.size.width < self.scrollView.bounds.size.width) {
        left = (self.scrollView.bounds.size.width - self.image.frame.size.width) * 0.5f;
    }
    if (self.image.frame.size.height < self.scrollView.bounds.size.height) {
        top = ((self.scrollView.bounds.size.height - self.image.frame.size.height) * 0.5f);
    }
    self.scrollView.contentInset = UIEdgeInsetsMake(top, left, top, left);
}

- (void)animateMinimumZoomScaleWithScale:(float)scale
{
    [self.scrollView setMinimumZoomScale:scale];
    [self.scrollView setZoomScale:scale animated:YES];
    [UIView animateWithDuration:animationSpeed animations:^{
        [self centerContent];
    } completion:NULL];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Rotation

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self animateMinimumZoomScaleWithScale:[self calculateScale]];
}

@end
