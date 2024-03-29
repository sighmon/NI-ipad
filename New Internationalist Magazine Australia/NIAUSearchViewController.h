//
//  NIAUSearchViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 16/10/13.
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
@import Firebase;

@interface NIAUSearchViewController : UITableViewController <UISearchBarDelegate, UISearchResultsUpdating>

@property (nonatomic, strong) NIAUIssue *issue;
@property (nonatomic, strong) NSMutableArray *issuesArray;
//@property (nonatomic, strong) NSMutableArray *filteredIssuesArray;
@property (nonatomic, strong) NSMutableArray *filteredIssueArticlesArray;
@property (nonatomic, strong) NSMutableArray *webSearchArticlesArray;

//@property IBOutlet UISearchBar *articleSearchBar;
@property (nonatomic, strong) UISearchController *searchController;

@end
