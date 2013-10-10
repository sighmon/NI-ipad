//
//  NIAUStoreViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 8/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUInAppPurchaseHelper.h"

@interface NIAUStoreViewController : UITableViewController

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *tableViewLoadingIndicator;

@property (nonatomic, weak) IBOutlet UILabel *subscriptionExpiryDateLabel;

@end
