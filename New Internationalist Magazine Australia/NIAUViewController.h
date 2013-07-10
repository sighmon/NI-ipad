//
//  NIAUViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 20/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUIssue.h"
#import "NIAUPublisher.h"

@interface NIAUViewController : UIViewController <UIGestureRecognizerDelegate>

@property (nonatomic, strong) NIAUIssue *issue;

@property (nonatomic, strong) IBOutlet UIImageView *cover;

@property (nonatomic, weak) IBOutlet UIButton *magazineArchiveButton;
@property (nonatomic, weak) IBOutlet UIButton *subscribeButton;
@property (nonatomic, weak) IBOutlet UIButton *loginButton;

@end
