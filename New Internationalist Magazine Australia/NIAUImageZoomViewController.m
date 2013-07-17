//
//  NIAUImageZoomViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 9/07/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUImageZoomViewController.h"

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
    
//    // calculate minimum scale to perfectly fit image width, and begin at that scale
//    float minimumScale = [self.scrollView frame].size.width  / [self.image frame].size.width;
//    [self.scrollView setMinimumZoomScale:minimumScale];
//    [self.scrollView setZoomScale:minimumScale];
    
//    // centre vertically
//    if (self.image.frame.size.height <= self.scrollView.frame.size.height)
//    {
//        NSLog(@"%@, %@", NSStringFromCGPoint(self.image.center), NSStringFromCGPoint(self.scrollView.center));
//        [self.image setCenter:[self.scrollView center]];
//    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.image;
}

#pragma mark -
#pragma mark Responding to gestures

- (IBAction)tapToHideNavigation:(UITapGestureRecognizer *)gestureRecognizer
{
    #define animationSpeed 0.3
    
    // Tap once to show/hide navigation
    if (!self.navigationController.navigationBarHidden) {
//        NSLog(@"Tapped to hide");
        [[self navigationController] setNavigationBarHidden:YES animated:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
        [UIView animateWithDuration:animationSpeed animations:^{
            [self.scrollView setBackgroundColor:[UIColor blackColor]];
        } completion:NULL];
    } else {
//        NSLog(@"Tapped to show");
        [[self navigationController] setNavigationBarHidden:NO animated:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
        [UIView animateWithDuration:animationSpeed animations:^{
            [self.scrollView setBackgroundColor:[UIColor whiteColor]];
        } completion:NULL];
    }
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
