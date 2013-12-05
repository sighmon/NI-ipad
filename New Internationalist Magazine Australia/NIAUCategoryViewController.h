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

@interface NIAUCategoryViewController : UITableViewController

@property (nonatomic, strong) NIAUIssue *issue;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, strong) NSMutableArray *issuesArray;
@property (nonatomic, strong) NSMutableArray *articlesArray;

@end
