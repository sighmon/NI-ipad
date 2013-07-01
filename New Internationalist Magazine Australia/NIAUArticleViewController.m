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
    
//    [self.scrollView setFrame:CGRectMake(0, 0, 320, 504)];
//    [self.scrollView setContentSize:CGSizeMake(320, 1000)];
//    [self.scrollView setScrollEnabled:YES];
//    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
//    self.featuredImage.translatesAutoresizingMaskIntoConstraints = NO;
//    self.secondTestImage.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.featuredImage.image = [UIImage imageNamed:@"default_cover.png"];
    self.secondTestImage.image = [UIImage imageNamed:@"default_cover.png"];
    
    // Set the constraints for the scroll view and the image view.
//    NSDictionary *viewsDictionary;
//    UIScrollView *scrollView = self.scrollView;
//    UIImageView *featuredImage = self.featuredImage;
//    UIImageView *secondTestImage = self.secondTestImage;
//    viewsDictionary = NSDictionaryOfVariableBindings(scrollView, featuredImage, secondTestImage);
//    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[scrollView]|" options:0 metrics: 0 views:viewsDictionary]];
//    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[scrollView]|" options:0 metrics: 0 views:viewsDictionary]];
//    [self.scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[featuredImage]|" options:0 metrics: 0 views:viewsDictionary]];
//    [self.scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[featuredImage]|" options:0 metrics: 0 views:viewsDictionary]];
//    [self.scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[secondTestImage]|" options:0 metrics: 0 views:viewsDictionary]];
//    [self.scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[secondTestImage]|" options:0 metrics: 0 views:viewsDictionary]];
}

// Solution to scrolling?
// http://stackoverflow.com/questions/14077367/why-wont-uiscrollview-scroll-fully-after-adding-objects-using-storyboard-arc

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    float heightOfContent = 0;
    UIView *lLast = [self.scrollView.subviews lastObject];
    NSInteger origin = lLast.frame.origin.y;
    NSInteger height = lLast.frame.size.height;
    heightOfContent = origin + height;
    
    NSLog(@"%@", [NSString stringWithFormat:@"Origin: %ld, height: %ld, total: %f", (long)origin, (long)height, heightOfContent]);
    
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.frame.size.width, heightOfContent)];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
