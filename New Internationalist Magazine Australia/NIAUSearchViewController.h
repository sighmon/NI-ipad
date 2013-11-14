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

@interface NIAUSearchViewController : UITableViewController <UISearchBarDelegate, UISearchDisplayDelegate>

@property (nonatomic, strong) NIAUIssue *issue;
@property (nonatomic, strong) NSMutableArray *issuesArray;
//@property (nonatomic, strong) NSMutableArray *filteredIssuesArray;
@property (nonatomic, strong) NSMutableArray *filteredIssueArticlesArray;

@property IBOutlet UISearchBar *articleSearchBar;

@end