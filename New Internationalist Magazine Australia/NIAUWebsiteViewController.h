//
//  NIAUWebsiteViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 6/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUArticle.h"

@interface NIAUWebsiteViewController : UIViewController <UIWebViewDelegate>

@property (nonatomic, weak) NIAUArticle *article;

@property (nonatomic, weak) NSURLRequest *linkToLoad;

@property (nonatomic, weak) IBOutlet UIWebView *webView;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *dismissModal;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *browserBack;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *browserForward;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *browserRefresh;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *browserShare;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *browserURL;

@end
