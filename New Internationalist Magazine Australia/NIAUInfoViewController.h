//
//  NIAUInfoViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 21/02/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NIAUInfoViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UIBarButtonItem *dismissModal;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *sendFeedback;
@property (nonatomic, weak) IBOutlet UITextView *versionNumber;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *versionNumberHeight;

@end
