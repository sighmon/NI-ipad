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
    
    self.featuredImage.image = [UIImage imageNamed:@"default_cover.png"];
    self.secondTestImage.image = [UIImage imageNamed:@"default_cover.png"];
    
}

//    Solution to scrolling?
//    http://stackoverflow.com/questions/14077367/why-wont-uiscrollview-scroll-fully-after-adding-objects-using-storyboard-arc

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // Not used.. manually setting the scrollView to the height of the lowest content.
    
    float heightOfContent = 0;
    UIView *lLast = [self.scrollView.subviews lastObject];
    NSLog(@"%@", lLast);
    NSInteger origin = lLast.frame.origin.y;
    NSInteger height = lLast.frame.size.height;
    heightOfContent = origin + height;
    
    NSLog(@"%@", [NSString stringWithFormat:@"Origin: %ld, height: %ld, total: %f", (long)origin, (long)height, heightOfContent]);
    
//    [self.scrollView setContentSize:CGSizeMake(self.scrollView.frame.size.width, heightOfContent)];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
