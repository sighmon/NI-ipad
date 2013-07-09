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
}

#pragma mark -
#pragma mark Responding to gestures

- (IBAction)showGestureForPinchRecognizer:(UIPinchGestureRecognizer *)gestureRecognizer
{    
    // Test gestures.
    NSLog(@"Pinched!");
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
