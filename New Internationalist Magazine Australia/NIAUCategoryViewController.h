//
//  NIAUCategoryViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 5/12/2013.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUPublisher.h"
#import "NIAUIssue.h"
#import "NIAUArticleViewController.h"

#import "GAI.h"
#import "GAITracker.h"
#import "GAITrackedViewController.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "GAILogger.h"

@interface NIAUCategoryViewController : UITableViewController

@property (nonatomic, strong) NIAUIssue *issue;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, strong) NSMutableArray *issuesArray;
@property (nonatomic, strong) NSMutableArray *articlesArray;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *tableViewLoadingIndicator;
@property (nonatomic, weak) IBOutlet UIView *loadingIndicatorView;

@end
