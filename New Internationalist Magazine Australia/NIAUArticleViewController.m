//
//  NIAUArticleViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUArticleViewController.h"
#import "NIAUImageZoomViewController.h"

@interface NIAUArticleViewController ()

@end

@implementation NIAUArticleViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showImageZoom"])
    {
        // TODO: Load the large version of the image to be zoomed.
        NIAUImageZoomViewController *imageZoomViewController = [segue destinationViewController];
        
        if ([sender isKindOfClass:[UIImageView class]]) {
            UIImageView *imageTapped = (UIImageView *)sender;
            imageZoomViewController.imageToLoad = imageTapped.image;
        } else {
            imageZoomViewController.imageToLoad = [UIImage imageNamed:@"default_article_image.png"];
        }
    }
}

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
    
    NSLog(@"TODO: Get the real article images.");
    [self.featuredImage setImage:[UIImage imageNamed:@"default_featured_image.png"]];
    [self.secondTestImage setImage:[UIImage imageNamed:@"default_article_image.png"]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:ArticleDidUpdateNotification object:self.article];
    
    [self.article requestBody];
    
    [self setupData];
    
    [self updateScrollViewContentHeight];
}

-(void)publisherReady:(NSNotification *)notification
{
    [self showArticle];
}

-(void)showArticle
{
    [self adjustHeightOfWebView];
}

- (void)adjustHeightOfWebView
{
    // TODO: work out how to find the height of a UIWebView
    
//    CGFloat height = self.bodyWebView.contentSize.height;
//    
//    // now set the height constraint accordingly
//    
//    [UIView animateWithDuration:0.25 animations:^{
//        self.tableViewHeightConstraint.constant = height;
//        [self.view needsUpdateConstraints];
//    }];
}

- (void)setupData
{
    self.titleLabel.text = self.article.title;
    self.teaserLabel.text = self.article.teaser;
    self.authorLabel.text = self.article.author;
    [self.bodyWebView loadHTMLString:self.article.body baseURL:nil];
}

- (void)updateScrollViewContentHeight
{
    CGRect contentRect = CGRectZero;
    for (UIView *view in self.scrollView.subviews) {
        contentRect = CGRectUnion(contentRect, view.frame);
    }
    self.scrollView.contentSize = contentRect.size;
}

#pragma mark -
#pragma mark Responding to gestures

- (IBAction)handleFeaturedImageSingleTap:(UITapGestureRecognizer *)recognizer
{
    // Handle image being tapped
    [self performSegueWithIdentifier:@"showImageZoom" sender:recognizer.view];
}

- (IBAction)handleSecondTestImageSingleTap:(UITapGestureRecognizer *)recognizer
{
    // Handle image being tapped
    [self performSegueWithIdentifier:@"showImageZoom" sender:recognizer.view];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
