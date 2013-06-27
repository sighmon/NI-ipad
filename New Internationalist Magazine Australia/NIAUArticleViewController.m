//
//  NIAUArticleViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUArticleViewController.h"

@interface NIAUArticleViewController ()

@end

@implementation NIAUArticleViewController

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
    
    // TODO: Make the scrollView scroll! Help me obiewan, you're my only hope.
    
    [self.scrollView setFrame:CGRectMake(0, 0, 320, 504)];
    [self.scrollView setContentSize:CGSizeMake(320, 1000)];
    [self.scrollView setScrollEnabled:YES];
    self.featuredImage.image = [UIImage imageNamed:@"default_cover.png"];
    self.secondTestImage.image = [UIImage imageNamed:@"default_cover.png"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
