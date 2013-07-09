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

// Handle image being tapped

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showImageZoom"])
    {        
        // TODO: Load the large version of the image to be zoomed.
        // load the image, to prevent it from being cached we use 'initWithContentsOfFile'
        NIAUImageZoomViewController *imageZoomViewController = [segue destinationViewController];
        imageZoomViewController.imageToLoad = [UIImage imageNamed:@"default_article_image.png"];
    }
}

- (IBAction)imageTapped:(id)sender
{
    [self performSegueWithIdentifier:@"showImageZoom" sender:self];
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
    
}

//    Solution to scrolling?
//    http://stackoverflow.com/questions/14077367/why-wont-uiscrollview-scroll-fully-after-adding-objects-using-storyboard-arc

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // Not used.. manually setting the scrollView to the height of the lowest content.
    
//    float heightOfContent = 0;
//    UIView *lLast = [self.scrollView.subviews lastObject];
//    NSLog(@"%@", lLast);
//    NSInteger origin = lLast.frame.origin.y;
//    NSInteger height = lLast.frame.size.height;
//    heightOfContent = origin + height;
//    
//    NSLog(@"%@", [NSString stringWithFormat:@"Origin: %ld, height: %ld, total: %f", (long)origin, (long)height, heightOfContent]);
    
//    [self.scrollView setContentSize:CGSizeMake(self.scrollView.frame.size.width, heightOfContent)];
    
    // Set the scrollView content height to the bodyTextView.
    
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.frame.size.width, self.bodyTextView.frame.origin.y + self.bodyTextView.frame.size.height)];
    
    // Wrap the text around the editor's photo
    
    CGRect secondTestImageRect = [self.bodyTextView convertRect:CGRectMake(self.secondTestImage.frame.origin.x-10, self.secondTestImage.frame.origin.y-10, self.secondTestImage.frame.size.width+20, self.secondTestImage.frame.size.height+20) fromView:self.scrollView];
    self.bodyTextView.textContainer.exclusionPaths = @[[UIBezierPath bezierPathWithRect:secondTestImageRect]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
