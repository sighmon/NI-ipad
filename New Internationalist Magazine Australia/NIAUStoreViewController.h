//
//  NIAUStoreViewController.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 8/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAUInAppPurchaseHelper.h"
#import "NIAUTableOfContentsViewController.h"

#import "GAI.h"
#import "GAITracker.h"
#import "GAITrackedViewController.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "GAILogger.h"

@interface NIAUStoreViewController : UITableViewController

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *tableViewLoadingIndicator;

@property (nonatomic, weak) IBOutlet UILabel *subscriptionTitle;
@property (nonatomic, weak) IBOutlet UILabel *subscriptionExpiryDateLabel;

@end
