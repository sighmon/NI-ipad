//
//  NIAUInfoViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 21/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUWebsiteViewController.h"
#import "NIAUHelper.h"

#import "GAI.h"
#import "GAITracker.h"
#import "GAITrackedViewController.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "GAILogger.h"
@import Firebase;

@interface NIAUInfoViewController : UIViewController <UITextFieldDelegate, UIWebViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIWebView *aboutWebView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *aboutWebViewHightConstraint;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *dismissModal;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *sendFeedback;
@property (nonatomic, weak) IBOutlet UITextView *versionNumber;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *versionNumberHeight;
@property (nonatomic, weak) IBOutlet UISwitch *analyticsSwitch;
@property (nonatomic, weak) IBOutlet UISwitch *helpSwitch;
@property (nonatomic, weak) IBOutlet UILabel *aboutLabel;
@property (nonatomic, weak) IBOutlet UIButton *deleteCacheButton;

- (IBAction)switchChanged: (id)sender;

@end
