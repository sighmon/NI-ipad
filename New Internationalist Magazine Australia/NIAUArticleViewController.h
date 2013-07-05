//
//  NIAUArticleViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NIAUArticleViewController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;

@property (nonatomic, strong) IBOutlet UIImageView *featuredImage;
@property (nonatomic, strong) IBOutlet UIImageView *secondTestImage;

@property (nonatomic, weak) IBOutlet UITextView *bodyTextView;

@end
