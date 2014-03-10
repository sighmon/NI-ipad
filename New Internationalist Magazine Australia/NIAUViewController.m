//
//  NIAUViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 20/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUViewController.h"
#import "NIAUMagazineArchiveViewController.h"
#import "NIAUTableOfContentsViewController.h"
#import "NIAUStoreViewController.h"
#import <SSKeychain.h>
#import "local.h"

@interface NIAUViewController ()
{
    NIAUIssue *lastIssue;
    NIAUArticle *firstArticle;
}

@end

@implementation NIAUViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.isUserLoggedIn = false;
    self.isUserASubscriber = false;
    self.showNewIssueBanner = false;
    self.issueBanner.hidden = true;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(articleBodyLoaded:) name:ArticleDidUpdateNotification object:self.article];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(articleBodyDidntLoad:) name:ArticleFailedUpdateNotification object:self.article];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshView:) name:@"refreshViewNotification" object:nil];
    
    [self setupView];
    
    //publisher = [[NIAUPublisher alloc] init];
    
    // Set the navigation bar to a colour.
//    self.navigationController.navigationBar.barTintColor = [UIColor redColor];
    
#ifdef DEBUG
    if ([[[NSProcessInfo processInfo] environment] objectForKey:@"TESTING"]) {
        NSLog(@"suppressing load during test");
        return;
    }
#endif
    
    if([[NIAUPublisher getInstance] isReady]) {
        [self showIssues];
    } else {
        [self loadIssues];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    // Check for a saved username/password in the keychain and then try and login
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [self loginToRails];
    });
    
    [self sendGoogleAnalyticsStats];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ArticleDidUpdateNotification object:self.article];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ArticleFailedUpdateNotification object:self.article];
}

- (void)setupView
{
//    How to set the navigation tint colour.
//    [self.navigationController.navigationBar setBarTintColor:[UIColor blueColor]];
    self.navigationController.navigationBarHidden = true;
    
    // Style buttons
//    [self.magazineArchiveButton setBackgroundColor:[UIColor clearColor]];
    
    // Call this to set a nice background gradient
    [NIAUHelper drawGradientInView:self.view];
}

- (void)sendGoogleAnalyticsStats
{
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:@"Home"];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createAppView] build]];
}

- (void)updateNewIssueBanner
{
    // Make it a circle
    self.issueBanner.layer.masksToBounds = YES;
    self.issueBanner.layer.cornerRadius = self.issueBanner.bounds.size.width / 2.;
    
    if (self.showNewIssueBanner) {
        self.issueBanner.hidden = NO;
        [self.view setNeedsLayout];
    } else {
        self.issueBanner.hidden = YES;
        [self.view setNeedsLayout];
    }
}

- (void)loadLatestMagazineCover
{
    [self.issue getCoverWithCompletionBlock:^(UIImage *img) {
        [self.cover setContentMode:UIViewContentModeScaleAspectFit];
        [self.cover setAlpha:0.0];
        [self.cover setImage:[NIAUHelper imageWithRoundedCornersSize:10. usingImage:img]];
        [self.issueBanner setAlpha:0.0];
        [self updateNewIssueBanner];
        [NIAUHelper addShadowToImageView:self.cover withRadius:10. andOffset:CGSizeMake(0, 5) andOpacity:0.5];
        [UIView animateWithDuration:0.5 animations:^{
            [self.cover setAlpha:1.0];
            [self.issueBanner setAlpha:1.0];
        }];
        // update the NewsStand icon
        [self updateNewsStandMagazineCover:img];
    }];
}

- (void)updateNewsStandMagazineCover: (UIImage *)cover
{
    if(cover) {
        [[UIApplication sharedApplication] setNewsstandIconImage:cover];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - NIAUPublisher interaction

-(void)loadIssues {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherFailed:) name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];
    [[NIAUPublisher getInstance] requestIssues];
}

-(void)publisherReady:(NSNotification *)not {
    // might recieve this more than once
    //[[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    //[[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];
    [self showIssues];
    [self loadLatestMagazineCover];
}

-(void)publisherFailed:(NSNotification *)not {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];
    NSLog(@"%@",not);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:@"Cannot get issues from publisher server."
                                                   delegate:nil
                                          cancelButtonTitle:@"Close"
                                          otherButtonTitles:nil];
    [alert show];
    //[alert release];
    //[self.navigationItem setRightBarButtonItem:refreshButton];
}

- (void)articleBodyLoaded:(NSNotification *)notification
{
    self.isUserASubscriber = YES;
    [self updateSubscribeButton];
}

- (void)articleBodyDidntLoad:(NSNotification *)notification
{
    self.isUserASubscriber = NO;
    [self updateSubscribeButton];
}

- (void)articlesReady:(NSNotification *)notification
{
    [self checkIfUserIsASubscriber];
}

- (void)refreshView:(NSNotification *)notification
{
    // Reload self.issue
    self.issue = [[NIAUPublisher getInstance] issueAtIndex:0];
    [self loadLatestMagazineCover];
    
    // Update the view
    [self.view setNeedsDisplay];
}

-(void)showIssues {
    // maybe un-grey magazinearchive button here?
    
    //[self.navigationItem setRightBarButtonItem:refreshButton];
    //table_.alpha=1.0;
    //[table_ reloadData];
    
    // Check to see if there are any new issues available
    NSURL *issuesURL = [NSURL URLWithString:@"issues.json" relativeToURL:[NSURL URLWithString:SITE_URL]];
    NSLog(@"try to download issues.json from %@", issuesURL);
    NSData *data = [NSData dataWithContentsOfCookielessURL:issuesURL];
    NSArray *tmpIssues = @[];
    if(data) {
        NSError *error;
        tmpIssues = [NSJSONSerialization JSONObjectWithData:data
                                                    options:kNilOptions
                                                      error:&error];
    }
    if ([[NIAUPublisher getInstance] numberOfIssues] < tmpIssues.count) {
        // A new issue is available, so force reload
        [[NIAUPublisher getInstance] forceDownloadIssues];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshViewNotification" object:nil];
        self.showNewIssueBanner = true;
    } else {
        // No issues to load
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(articlesReady:) name:ArticlesDidUpdateNotification object:lastIssue];
        self.issue = [[NIAUPublisher getInstance] issueAtIndex:0];
        [self.issue requestArticles];
        lastIssue = [[NIAUPublisher getInstance] lastIssue];
        [lastIssue requestArticles];
    }
}

- (void)loginToRails
{    
    // Get keychain details
    NSError *keychainError = nil;
    id keychainAccount = [[SSKeychain accountsForService:@"NIWebApp"] firstObject];
    NSString *username = keychainAccount[@"acct"];
    NSString *password = [SSKeychain passwordForService:@"NIWebApp" account:keychainAccount[@"acct"] error:&keychainError];
    
    if (keychainError == nil) {
        NSLog(@"Account found: %@", username);
        
        // Try logging in to Rails.
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"users/sign_in.json?password=%@&username=%@", password, username] relativeToURL:[NSURL URLWithString:SITE_URL]]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        NSData *postData = [[NSString stringWithFormat:@"user[login]=%@&user[password]=%@",username,password] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *postLength = [NSString stringWithFormat:@"%d", (int)[postData length]];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody:postData];
        
        NSError *error;
        NSHTTPURLResponse *response;
        //        NSData *responseData =
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
        int statusCode = (int)[response statusCode];
        if(statusCode >= 200 && statusCode < 300) {
            // Logged in!
            NSLog(@"Logged in user: %@", username);
            self.isUserLoggedIn = true;
            [self updateLoginButton];
//            [self checkIfUserIsASubscriber];
        } else {
            // Something went wrong, but don't show the user.
            NSLog(@"Couldn't log in user: %@", username);
            self.isUserLoggedIn = false;
            [self updateLoginButton];
        }
    } else {
        NSLog(@"Uh oh: %@", keychainError);
    }

}

- (void)checkIfUserIsASubscriber
{
    firstArticle = [lastIssue articleAtIndex:0];
    // TODO: Write a method here that checks a specific rails route for a vaild sub or iTunes receipt
    [firstArticle requestBody];
    [self updateSubscribeButton];
}

- (void)updateLoginButton
{
    if (self.isUserLoggedIn) {
//        self.loginButton.hidden = YES;
//        [self.loginButton.constraints[0] setConstant:0.01f];
//        [self.loginButton setNeedsUpdateConstraints];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loginButton layoutIfNeeded];
//            self.loginButton.enabled = NO;
            [self.loginButton setTitle:@"Logged in" forState:UIControlStateNormal];
            NSLog(@"Logged in.");
        });
    } else {
//        self.loginButton.hidden = NO;
//        [self.loginButton.constraints[0] setConstant:38];
//        [self.loginButton setNeedsUpdateConstraints];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loginButton layoutIfNeeded];
            self.loginButton.enabled = YES;
            NSLog(@"Not logged in.");
        });
    }
}

- (void)updateSubscribeButton
{
    if (self.isUserASubscriber) {
//        self.subscribeButton.hidden = YES;
//        [self.subscribeButton.constraints[0] setConstant:0.01f];
//        [self.subscribeButton setNeedsUpdateConstraints];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.subscribeButton layoutIfNeeded];
            self.subscribeButton.enabled = NO;
            [self.subscribeButton setTitle:@"Thanks for subscribing" forState:UIControlStateDisabled];
            NSLog(@"Subscription button disabled.");
        });
    } else {
//        self.subscribeButton.hidden = NO;
//        [self.subscribeButton.constraints[0] setConstant:38];
//        [self.subscribeButton setNeedsUpdateConstraints];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.subscribeButton layoutIfNeeded];
            self.subscribeButton.enabled = YES;
            NSLog(@"Subscription button enabled.");
        });
    }
}

#pragma mark -
#pragma mark Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"homeCoverToContentsView"])
    {
        // Send you to the latest issue
        
        NIAUTableOfContentsViewController *tableOfContentsViewController = [segue destinationViewController];
        if (self.issue) {
            tableOfContentsViewController.issue = self.issue;
        } else {
            tableOfContentsViewController.issue = [[NIAUPublisher getInstance] issueAtIndex:0];
        }
        
    } else if ([[segue identifier] isEqualToString:@"subscribeButtonToStoreView"]) {
        // If there's anything to do, do it here.
        
    } else if ([[segue identifier] isEqualToString:@"searchButtonToSearchView"]) {
        // If there's anything to do, do it here.
        
    } else if ([[segue identifier] isEqualToString:@"categoriesButtonToCategoriesView"]) {
        // If there's anything to do, do it here.
    }
}

#pragma mark -
#pragma mark Tap recognizers

- (IBAction)coverTapped:(UITapGestureRecognizer *)recognizer
{
    NSLog(@"Cover tapped!");
    [self performSegueWithIdentifier:@"homeCoverToContentsView" sender:self];
}

- (IBAction)magazineArchiveButtonTapped:(id)sender
{
    
}

- (IBAction)subscribeButtonTapped:(id)sender
{
    
}

- (IBAction)loginButtonTapped:(id)sender
{
    
}

#pragma mark - Navigation Controller show/hide

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.alpha = 0.0f;
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    
    [UIView animateWithDuration:0.5f animations:^{
        self.navigationController.navigationBar.alpha = 1.0f;
    } completion:^(BOOL finished) {}];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    
    [UIView animateWithDuration:0.5f animations:^{
        self.navigationController.navigationBar.alpha = 0.0f;
    } completion:^(BOOL finished) {}];
}

@end
