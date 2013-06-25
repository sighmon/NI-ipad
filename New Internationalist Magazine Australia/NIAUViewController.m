//
//  NIAUViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 20/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUViewController.h"

@interface NIAUViewController ()

@end

@implementation NIAUViewController

- (IBAction)magazineArchiveButtonTapped:(id)sender {
    NSLog(@"TODO: Load the UICollectionView of magazine covers.");
}

- (IBAction)subscribeButtonTapped:(id)sender {
    NSLog(@"TODO: Load the Subscription options view.");
}

- (IBAction)loginButtonTapped:(id)sender {
    NSLog(@"TODO: Load the page to login to rails.");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"TODO: Grab most recent Issue cover.");
    [self.cover setImage:[UIImage imageNamed:@"default_cover.png"]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
