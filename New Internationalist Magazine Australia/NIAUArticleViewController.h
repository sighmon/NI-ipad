//
//  NIAUArticleViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUArticle.h"
#import "NIAUIssue.h"
#import "NIAUCategoryViewController.h"
#import "NIAUWebsiteViewController.h"
#import "NIAUHelper.h"

#import "GAI.h"
#import "GAITracker.h"
#import "GAITrackedViewController.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "GAILogger.h"
@import Firebase;

extern NSString *ArticleDidRefreshNotification;

@interface NIAUArticleViewController : UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate, UIWebViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) NIAUArticle *article;

@property (atomic) BOOL isArticleBodyLoaded;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *webViewLoadingIndicator;

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;

@property (nonatomic, strong) IBOutlet UIImageView *featuredImage;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *titleViewWidthConstraint;
@property (weak, nonatomic) IBOutlet UILabel *teaserLabel;
@property (weak, nonatomic) IBOutlet UIButton *dateButton;
@property (weak, nonatomic) IBOutlet UILabel *authorLabel;
@property (weak, nonatomic) IBOutlet UIWebView *bodyWebView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bodyWebViewHeightConstraint;

@property (weak, nonatomic) IBOutlet UICollectionView *categoryCollectionView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *categoryCollectionViewHeightConstraint;

@property (weak, nonatomic) IBOutlet UINavigationItem *shareAction;

@property (weak, nonatomic) IBOutlet UISwipeGestureRecognizer *swipeLeft;
@property (weak, nonatomic) IBOutlet UISwipeGestureRecognizer *swipeRight;

@property (strong, nonatomic) UIAlertView *alertView;

@end
