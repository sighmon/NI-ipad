//
//  NIAUTableOfContentsViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 26/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUIssue.h"
#import "NIAUArticleViewController.h"
#import "NIAUPublisher.h"
#import "NIAUWebsiteViewController.h"
#import "NIAUHelper.h"
#import "NIAUInAppPurchaseHelper.h"
#import "Reachability.h"

#import "GAI.h"
#import "GAITracker.h"
#import "GAITrackedViewController.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "GAILogger.h"
@import Firebase;

@interface NIAUTableOfContentsViewController : UIViewController <UIScrollViewDelegate, UITextViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) NIAUIssue *issue;

@property (nonatomic, strong) UIImage *cover;

@property (nonatomic, strong) NSArray *sortedCategories;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSMutableDictionary *cellDictionary;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *tableViewHeightConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *editorsLetterTextViewHeightConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *magazineCoverWidthConstraint;

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UITextView *editorsLetterTextView;
@property (nonatomic, weak) IBOutlet UIImageView *editorImageView;
@property (nonatomic, weak) IBOutlet UIView *tableViewFooterView;

@property (nonatomic, weak) IBOutlet UILabel *labelTitle;
@property (nonatomic, weak) IBOutlet UILabel *labelNumberAndDate;
@property (nonatomic, weak) IBOutlet UILabel *labelEditor;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *tableViewArticleTitleHeightConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *tableViewArticleTeaserHeightConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *tableViewCellHeightConstraint;

@property (nonatomic, weak) IBOutlet UINavigationItem *shareAction;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@property (nonatomic, strong) UIAlertView *alertView;

@end
