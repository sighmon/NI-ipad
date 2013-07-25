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

@interface NIAUViewController ()

@end

@implementation NIAUViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"homeCoverToContentsView"])
    {        
        // Do any extra setup here if needed.
        
        NSLog(@"TODO: Send the latest magazine ID to the tableOfContentsViewController");
        
        NIAUTableOfContentsViewController *tableOfContentsViewController = [segue destinationViewController];
        tableOfContentsViewController.cover = [UIImage imageNamed:@"default_cover.png"];
    }
}

- (IBAction)coverTapped:(UITapGestureRecognizer *)recognizer
{
    NSLog(@"Cover tapped!");
    [self performSegueWithIdentifier:@"homeCoverToContentsView" sender:self];
}

- (IBAction)magazineArchiveButtonTapped:(id)sender
{
    NSLog(@"TODO: Load the UICollectionView of magazine covers.");
}

- (IBAction)subscribeButtonTapped:(id)sender
{
    NSLog(@"TODO: Load the Subscription options view.");
}

- (IBAction)loginButtonTapped:(id)sender
{
    NSLog(@"TODO: Load the page to login to rails.");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"TODO: Grab most recent Issue cover.");
    [self.cover setImage:[UIImage imageNamed:@"default_cover.png"]];
    
//    // Shadow for the latest magazine cover
//    self.cover.layer.shadowColor = [UIColor blackColor].CGColor;
//    self.cover.layer.shadowOffset = CGSizeMake(0, 2);
//    self.cover.layer.shadowOpacity = 0.5;
//    self.cover.layer.shadowRadius = 3.0;
//    self.cover.clipsToBounds = NO;
    
    //publisher = [[NIAUPublisher alloc] init];
    
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


@end
