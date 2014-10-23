//
//  NIAUWebsiteViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 6/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import "NIAUWebsiteViewController.h"

@interface NIAUWebsiteViewController ()
{
    BOOL isPageLoaded;
    NSTimer *myTimer;
}

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
    
    [self sendGoogleAnalyticsStats];
}

- (void)sendGoogleAnalyticsStats
{
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:[NSString stringWithFormat:@"Webview - %@", [self.linkToLoad.URL absoluteString]]];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createAppView] build]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Button actions

- (IBAction)dismissButtonTapped:(id)sender
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    isPageLoaded = true;
    [self.progressView setHidden:YES];
    [self stopMyTimer];
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
    NSString *fromLink = @"";
    NSString *fromTitle = @"";
    if (self.article) {
        fromLink = [self.article.getGuestPassURL absoluteString];
        fromTitle = self.article.title;
    } else if (self.issue) {
        fromLink = [[self.issue getWebURL] absoluteString];
        fromTitle = self.issue.title;
    }
    NSMutableArray *itemsToShare = [[NSMutableArray alloc] initWithArray:@[[NSString stringWithFormat:@"A link I found reading '%@' from New Internationalist magazine.\n%@\n\nThe link is:", fromTitle, fromLink], self.webView.request.URL.absoluteString]];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [activityController setValue:[NSString stringWithFormat:@"Link from New Internationalist"] forKey:@"subject"];
    [[UINavigationBar appearance] setTintColor:self.view.tintColor];
    
    // Avoid the iOS 8 iPad crash
    if (IS_IPAD() && SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        activityController.popoverPresentationController.barButtonItem = sender;
    };
    
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
    isPageLoaded = false;
    myTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerCallback) userInfo:nil repeats:YES];
    [self.progressView setHidden:NO];
    self.browserURL.title = [[self.webView.request.URL URLByDeletingLastPathComponent] absoluteString];
    [self updateButtons];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    isPageLoaded = true;
    [self stopMyTimer];
    [self.progressView setHidden:YES];
    [self updateButtons];
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self.progressView setHidden:YES];
    [self stopMyTimer];
    [self updateButtons];
}

-(void)timerCallback {
    if (isPageLoaded) {
        if (self.progressView.progress >= 1) {
            [self.progressView setHidden:YES];
        }
        else {
            float progress = self.progressView.progress;
            float randomProgress = [self randomFloatWithMinimum:0.0 andMaximum:0.1];
            progress += randomProgress;
            [self.progressView setProgress:progress animated:YES];
        }
    }
    else {
        float progress = self.progressView.progress;
        float randomProgress = [self randomFloatWithMinimum:0.0 andMaximum:0.05];
        progress += randomProgress;
        [self.progressView setProgress:progress animated:YES];
        if (self.progressView.progress >= 0.95) {
            self.progressView.progress = 0.95;
        }
    }
}

-(void)stopMyTimer
{
    if(myTimer)
    {
        [myTimer invalidate];
        myTimer = nil;
    }
    [self resetProgressOfProgressView];
}

-(void)resetProgressOfProgressView
{
    [self.progressView setProgress:0.0 animated:NO];
}

-(float)randomFloatWithMinimum: (float)min andMaximum: (float)max
{
    // Randomise the progressView progress so it looks a bit more real.
    return ((arc4random()%RAND_MAX)/(RAND_MAX*1.0))*(max-min)+min;
}

@end
