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
    NSArray *_products;
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

    // Check for a saved username/password in the keychain and then try and login
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [self loginToRails];
    });
    
    if([[NIAUPublisher getInstance] isReady]) {
        [self showIssues];
    } else {
        [self loadIssues];
    }
    
}

- (void) setupView
{
//    How to set the navigation tint colour.
//    [self.navigationController.navigationBar setBarTintColor:[UIColor blueColor]];
    
    // Style buttons
//    [self.magazineArchiveButton setBackgroundColor:[UIColor clearColor]];
}

- (void)loadLatestMagazineCover
{
    [[[NIAUPublisher getInstance] issueAtIndex:0] getCoverWithCompletionBlock:^(UIImage *img) {
        [self.cover setAlpha:0.0];
        [self.cover setImage:img];
        [UIView animateWithDuration:0.5 animations:^{
            [self.cover setAlpha:1.0];
        }];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma - mark NIAUPublisher interaction

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

-(void)showIssues {
    // maybe un-grey magazinearchive button here?
    
    //[self.navigationItem setRightBarButtonItem:refreshButton];
    //table_.alpha=1.0;
    //[table_ reloadData];
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
        NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody:postData];
        
        NSError *error;
        NSHTTPURLResponse *response;
        //        NSData *responseData =
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
        int statusCode = [response statusCode];
        if(statusCode >= 200 && statusCode < 300) {
            // Logged in!
            NSLog(@"Logged in user: %@", username);
        } else {
            // Something went wrong, but don't show the user.
            NSLog(@"Couldn't log in user: %@", username);
        }
    } else {
        NSLog(@"Uh oh: %@", keychainError);
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
        tableOfContentsViewController.issue = [[NIAUPublisher getInstance] issueAtIndex:0];
        
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

@end
