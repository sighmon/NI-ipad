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

@interface NIAUTableOfContentsViewController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, strong) NIAUIssue *issue;

@property (nonatomic, strong) UIImage *cover;

@property (nonatomic, strong) NSMutableArray *categoriesArray;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSMutableDictionary *cellDictionary;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *editorsLetterTextViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *magazineCoverWidthConstraint;

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UITextView *editorsLetterTextView;
@property (nonatomic, weak) IBOutlet UIImageView *editorImageView;
@property (nonatomic, weak) IBOutlet UIView *tableViewFooterView;

@property (weak, nonatomic) IBOutlet UILabel *labelTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelNumberAndDate;
@property (weak, nonatomic) IBOutlet UILabel *labelEditor;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewArticleTitleHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewArticleTeaserHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewCellHeightConstraint;

@property (weak, nonatomic) IBOutlet UINavigationItem *shareAction;

@end
