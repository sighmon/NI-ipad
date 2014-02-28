//
//  NIAUInfoViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 21/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import "NIAUInfoViewController.h"

@interface NIAUInfoViewController ()

@property (nonatomic, weak) NSString *version;
@property (nonatomic, weak) NSString *build;

@end

@implementation NIAUInfoViewController

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
    
    [self setupView];
}

- (void)setupView
{
    // Update the version number
    self.version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    self.build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *aboutText = @"Need help? Ask us a question on Twitter: @ni_australia\n\nDesigned and built in \nAdelaide, Australia. \n\nDo you have any suggestions for future versions? Tap the share button (top right).";
    
    self.versionNumber.text = [NSString stringWithFormat:@"Version %@ (%@)\n\n%@", self.version, self.build, aboutText];
    self.versionNumber.editable = false;
    self.versionNumberHeight.constant = [self.versionNumber sizeThatFits:CGSizeMake(self.versionNumber.frame.size.width, CGFLOAT_MAX)].height + 1.0;
    
    // TODO: Add subscription expiry date information here.
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

- (IBAction)feedbackButtonTapped:(id)sender
{
    // Prepare email;
    NSMutableArray *itemsToShare = [[NSMutableArray alloc] initWithArray:@[[NSString stringWithFormat:@"I'm using the New Internationalist Magazine Australia app version %@ (%@), and my feedback/suggestions are:",self.version, self.build]]];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [activityController setValue:[NSString stringWithFormat:@"NI App feedback - %@ (%@)", self.version, self.build] forKey:@"subject"];
    [self presentViewController:activityController animated:YES completion:nil];
}

@end
