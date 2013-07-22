//
//  NIAUTableOfContentsViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 26/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUIssue.h"

@interface NIAUTableOfContentsViewController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, strong) NIAUIssue *issue;

@property (nonatomic, strong) UIImage *cover;

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UITextView *editorsLetterTextView;
@property (nonatomic, weak) IBOutlet UIImageView *editorImageView;

@property (weak, nonatomic) IBOutlet UILabel *labelTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelNumberAndDate;
@property (weak, nonatomic) IBOutlet UILabel *labelEditor;

@end
