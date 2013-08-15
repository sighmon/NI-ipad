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
    
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:ArticleDidUpdateNotification object:self.article];
    
    [self.article requestBody];
    
    [self setupData];
    
    [self updateScrollViewContentHeight];
}

-(void)publisherReady:(NSNotification *)notification
{
    [self setupData];
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
    // Tried to use system font.. seems to be different for webview
    // #define kbodyWebViewFont @"-apple-system-body"
    
    //Get the real article images.
    NSLog(@"pre getFeaturedImageWIthCompletionBlock");
    [self.article getFeaturedImageWithCompletionBlock:^(UIImage *img) {
        [self.featuredImage setImage:img];
        [self.featuredImage setNeedsLayout];
    }];
    NSLog(@"post getFeaturedImageWIthCompletionBlock");
    self.titleLabel.text = self.article.title;
    self.teaserLabel.text = self.article.teaser;
    self.authorLabel.text = self.article.author;
    
    // Load CSS from the filesystem
    NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"article-body" withExtension:@"css"];
    
    // Load the article into the webview
    NSString *bodyWebViewHTML = [NSString stringWithFormat:@"<html> \n"
                                   "<head> \n"
                                   "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\">"
                                   "</head> \n"
                                   "<body>%@</body> \n"
                                   "</html>", cssURL, self.article.body];
    [self.bodyWebView loadHTMLString:bodyWebViewHTML baseURL:nil];
    
    // Prevent webview from scrolling
    if ([self.bodyWebView respondsToSelector:@selector(scrollView)]) {
        self.bodyWebView.scrollView.scrollEnabled = NO;
    }
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
#pragma mark WebView delegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self.webViewLoadingIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.webViewLoadingIndicator stopAnimating];
    [self ensureScrollsToTop: webView];
    
    // Set the webview size
    CGSize size = [webView sizeThatFits: CGSizeMake(320., 1.)];
    CGRect frame = webView.frame;
    frame.size.height = size.height;
    webView.frame = frame;
    
    // Update the constraints.
    CGFloat contentHeight = webView.frame.size.height + 20;
    
    [UIView animateWithDuration:0.25 animations:^{
        self.bodyWebViewHeightConstraint.constant = contentHeight;
        [self.view needsUpdateConstraints];
    }];
}

- (void) ensureScrollsToTop: (UIView *) ensureView {
    ((UIScrollView *)[[self.bodyWebView subviews] objectAtIndex:0]).scrollsToTop = NO;
}

#pragma mark -
#pragma mark Social sharing

- (IBAction)shareActionTapped:(id)sender
{
    NSLog(@"Share tapped!");
    
    // TODO: Check that the image isn't a default image.
    
    NSArray *itemsToShare = @[[NSString stringWithFormat:@"I'm reading '%@'",self.article.title], self.featuredImage.image, self.article.getWebURL];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [self presentViewController:activityController animated:YES completion:nil];
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
