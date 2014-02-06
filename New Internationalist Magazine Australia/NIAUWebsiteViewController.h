//
//  NIAUWebsiteViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 6/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NIAUWebsiteViewController : UIViewController <UIWebViewDelegate>

@property (nonatomic, strong) NSURLRequest *linkToLoad;

@property (nonatomic, strong) IBOutlet UIWebView *webView;

@end
