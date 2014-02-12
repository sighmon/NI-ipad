//
//  NIAUWebsiteViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 6/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import "NIAUWebsiteViewController.h"

@interface NIAUWebsiteViewController ()

@end

@implementation NIAUWebsiteViewController

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
    
    [self.webView loadRequest:self.linkToLoad];
    self.browserURL.title = [self.linkToLoad.URL absoluteString];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Button actions

- (IBAction)dismissButtonTapped:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)backButtonTapped:(id)sender
{
    // Go back
    [self.webView goBack];
}

- (IBAction)forwardButtonTapped:(id)sender
{
    // Go forward
    [self.webView goForward];
}

- (IBAction)refreshButtonTapped:(id)sender
{
    // Refresh UIWebView
    [self.webView reload];
}

- (IBAction)shareButtonTapped:(id)sender
{
    // Pop share modal
    NSMutableArray *itemsToShare = [[NSMutableArray alloc] initWithArray:@[[NSString stringWithFormat:@"A link I found reading '%@' from New Internationalist magazine.\n\nThe original article is here:\n%@\n\nThe link is:", self.article.title, [self.article.getGuestPassURL absoluteString]], [self.linkToLoad.URL absoluteString]]];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [activityController setValue:[NSString stringWithFormat:@"Link from New Internationalist"] forKey:@"subject"];
    [self presentViewController:activityController animated:YES completion:nil];

}

- (void)updateButtons
{
    self.browserForward.enabled = self.webView.canGoForward;
    self.browserBack.enabled = self.webView.canGoBack;
}

#pragma mark - UIWebView delegate methods

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateButtons];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
}

@end
