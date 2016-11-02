//
//  NIAUStoreViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 8/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUStoreViewController.h"

@interface NIAUStoreViewController ()
{
    NSArray *_products;
    NSDictionary *_railsUserInfo;
    NSNumberFormatter *_priceFormatter;
}
@end

@implementation NIAUStoreViewController

#define kMagazineCoverWidth 70
#define kMagazineCoverHeight 100

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Subscribe";

    // Uncomment the following line to preserve selection between presentations.
    self.clearsSelectionOnViewWillAppear = YES;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Load the products from iTunesConnect
    _products = @[];
    [[NIAUInAppPurchaseHelper sharedInstance] requestProductsWithCompletionHandler:^(BOOL success, NSArray *products) {
        if (success) {
            _products = products;
            _railsUserInfo = [self getRailsUserInfo];
            [self.tableViewLoadingIndicator stopAnimating];
            [self.tableView reloadData];
            
            self.subscriptionExpiryDateLabel.text = @"(Or purchase an individual issue)";
            // Get expiry date if you have a subscription.
            [self updateExpiryDate];
        }
    }];
    
    // Format the price of each product for different locales.
    _priceFormatter = [[NSNumberFormatter alloc] init];
    [_priceFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [_priceFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    
    // Start Activity Indicator.
    self.subscriptionTitle.text = @"Yearly or quarterly subscriptions";
    self.subscriptionExpiryDateLabel.text = @"";
    [self.tableViewLoadingIndicator startAnimating];
    
    // Add observer for the user changing the text size
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    [self sendGoogleAnalyticsStats];
}

- (void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(productPurchased:) name:IAPHelperProductPurchasedNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (NSDictionary *)getRailsUserInfo
{
    // Try getting subscription expiry date from Rails
    NSData *subscriptionExpiryDate = [NIAUInAppPurchaseHelper getUserExpiryDateFromRailsAndAppStoreReceipt];
    
    if (subscriptionExpiryDate) {
        NSError *error = nil;
        NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:subscriptionExpiryDate options:kNilOptions error:&error];
        
        if (error != nil) {
            DebugLog(@"Error parsing JSON.");
            return nil;
        }
        else {
            // Got a response from Rails, return it.
            DebugLog(@"JSON: %@", jsonDictionary);
            return jsonDictionary;
        }
    } else {
        // Failed to get a response from rails
        return nil;
    }
}

- (void)updateExpiryDate
{
    if (_railsUserInfo) {
        // Display expiry date from rails
        if ([_railsUserInfo objectForKey:@"expiry"] != [NSNull null]) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];
            NSDate *date = [dateFormatter dateFromString:[_railsUserInfo objectForKey:@"expiry"]];
            NSLocale *userLocale = [[NSLocale alloc] initWithLocaleIdentifier:[[NSLocale preferredLanguages] objectAtIndex:0]];
            [dateFormatter setLocale:userLocale];
            [dateFormatter setDateStyle:NSDateFormatterLongStyle];
            [UIView animateWithDuration:0.5 animations:^{
                [self.subscriptionTitle setAlpha:0.0];
                [self.subscriptionExpiryDateLabel setAlpha:0.0];
                self.subscriptionTitle.text = @"Your subscription expiry:";
                self.subscriptionExpiryDateLabel.text = [dateFormatter stringFromDate:date];
                [self.subscriptionTitle setAlpha:1.0];
                [self.subscriptionExpiryDateLabel setAlpha:1.0];
            }];
        }
    } else {
        // No data available, so lets try iTunes
        DebugLog(@"No subscription data from Rails, sorry.");
        [self checkItunesForSubscriptionExpiry];
    }

}

- (void)checkItunesForSubscriptionExpiry
{
    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    [NIAUInAppPurchaseHelper validateReceiptWithData:receiptData completionHandler:^(BOOL success, NSString *response) {
        NSData *jsonData = [response dataUsingEncoding:NSUTF8StringEncoding];
        NSError *e;
        NSDictionary *receiptDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&e];
//        DebugLog(@"Receipt response: \n%d, %@", success, receiptDictionary);
        if (success && receiptDictionary && [[receiptDictionary objectForKey:@"status"] integerValue] == 0) {
            // Receipt is valid, lets check for the last expiry date we have.
            NSArray *purchases = [[receiptDictionary objectForKey:@"receipt"] objectForKey:@"in_app"];
            NSMutableDictionary *latestAutoDebit = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *latestNonRenewing = [[NSMutableDictionary alloc] init];
            [purchases enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                // Loop through and separate autos from single subs.
                BOOL isAuto = !([[obj objectForKey:@"product_id"] rangeOfString:@"auto"].location == NSNotFound);
                BOOL isSubscription = !([[obj objectForKey:@"product_id"] rangeOfString:@"month"].location == NSNotFound);
                if (isSubscription) {
                    if (isAuto) {
                        if ([latestAutoDebit count] == 0 || [[obj objectForKey:@"expires_date_ms"] doubleValue] > [[latestAutoDebit objectForKey:@"expires_date_ms"] doubleValue]) {
                            // This is the latest expiry, so add it
                            [latestAutoDebit addEntriesFromDictionary:obj];
                        }
                    } else {
                        if ([latestNonRenewing count] == 0 || [[obj objectForKey:@"original_purchase_date_ms"] doubleValue] > [[latestNonRenewing objectForKey:@"original_purchase_date_ms"] doubleValue]) {
                            // This is the latest expiry, so add it
                            [latestNonRenewing addEntriesFromDictionary:obj];
                        }
                    }
                }
            }];
            NSString *titleString = @"";
            NSTimeInterval dateInterval = 0;
            BOOL isLatestAnAuto = false;
            if ([latestAutoDebit count] > 0) {
                if ([latestNonRenewing count] > 0) {
                    if ([[latestAutoDebit objectForKey:@"expires_date_ms"] doubleValue] > [[latestNonRenewing objectForKey:@"original_purchase_date_ms"] doubleValue]) {
                        // Set autodebit information
                        titleString = @"Your next autodebit:";
                        dateInterval = [[latestAutoDebit objectForKey:@"expires_date_ms"] doubleValue];
                        isLatestAnAuto = true;
                    } else {
                        // Set non-auto information
                        titleString = @"Your subscription expiry:";
                        dateInterval = [[latestNonRenewing objectForKey:@"original_purchase_date_ms"] doubleValue];
                    }
                } else {
                    // Set autodebit information
                    titleString = @"Your next autodebit:";
                    dateInterval = [[latestAutoDebit objectForKey:@"expires_date_ms"] doubleValue];
                    isLatestAnAuto = true;
                }
                
            } else if ([latestNonRenewing count] > 0) {
                // Set non-auto information
                titleString = @"Your subscription expiry:";
                dateInterval = [[latestNonRenewing objectForKey:@"original_purchase_date_ms"] doubleValue];
            }
            if (dateInterval > 0) {
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:(dateInterval/1000)];
                
                if (!isLatestAnAuto) {
                    // We need to add the subscription duration to the date.
                    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
                    NSInteger monthsOfSubscription = [[[latestNonRenewing objectForKey:@"product_id"] substringToIndex:2] integerValue];
                    [dateComponents setMonth:monthsOfSubscription];
                    NSCalendar *calendar = [NSCalendar currentCalendar];
                    date = [calendar dateByAddingComponents:dateComponents toDate:date options:0];
                }
                
                NSLocale *userLocale = [[NSLocale alloc] initWithLocaleIdentifier:[[NSLocale preferredLanguages] objectAtIndex:0]];
                [dateFormatter setLocale:userLocale];
                [dateFormatter setDateStyle:NSDateFormatterLongStyle];
                [UIView animateWithDuration:0.5 animations:^{
                    [self.subscriptionTitle setAlpha:0.0];
                    [self.subscriptionExpiryDateLabel setAlpha:0.0];
                    self.subscriptionTitle.text = titleString;
                    self.subscriptionExpiryDateLabel.text = [dateFormatter stringFromDate:date];
                    [self.subscriptionTitle setAlpha:1.0];
                    [self.subscriptionExpiryDateLabel setAlpha:1.0];
                }];
            }
        }
    }];
}

- (void)sendGoogleAnalyticsStats
{
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:@"Subscribe"];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createScreenView] build]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)productPurchased:(NSNotification *)notification {
    
    NSString *productIdentifier = notification.object;
    [_products enumerateObjectsUsingBlock:^(SKProduct *product, NSUInteger idx, BOOL *stop) {
        if ([product.productIdentifier isEqualToString:productIdentifier]) {
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
            *stop = YES;
        }
    }];
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (_products) {
        return _products.count;
    } else {
        // TODO: set a default response for no products.
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"storeViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
    
    if (_products) {
        SKProduct *product = _products[indexPath.row];
        
        UIImageView *productImageView = (UIImageView *)[cell viewWithTag:100];
        productImageView.image = nil;
        if (productImageView.image == nil) {
            productImageView.image = [UIImage imageNamed:@"ni-logo-grey.png"];
            
            if (![self isProductASubscriptionAtRow:(int)indexPath.row]) {
                // It's a single issue so load the cover
                NIAUIssue *issue = [self issueAtIndexPath:indexPath];
                float pixelDepth = 2;
                if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
                    pixelDepth = [[UIScreen mainScreen] scale];
                }
                // Setting the cover size manually - as it was defaulting to 2000 x 2000
                CGSize coverSize = CGSizeMake(kMagazineCoverWidth * pixelDepth, kMagazineCoverHeight * pixelDepth);
                
                [issue getCoverThumbWithSize:coverSize andCompletionBlock:^(UIImage *img) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Is cell is still in view
                        if (img && [[tableView visibleCells] containsObject:cell]) {
                            
                            if (cell) {
                                //                                UIImageView *productImageView = (UIImageView *)[cell viewWithTag:100];
                                [productImageView setAlpha:0.0];
                                [productImageView layoutIfNeeded];
                                [productImageView setImage:[NIAUHelper imageWithRoundedCornersSize:3. usingImage:img]];
                                [UIView animateWithDuration:0.3 animations:^{
                                    [productImageView setAlpha:1.0];
                                }];
                            }
                        }
                    });
                }];
            }
        }
        
        BOOL purchased = [self hasProductBeenPurchasedAtRow:(int)indexPath.row];
        
//        if (purchased) {
//            // Leave background colour purchase green.
//            productImageView.backgroundColor = [[self.navigationController.navigationBar tintColor] colorWithAlphaComponent:0.1];
//        } else {
//            if ([self isProductASubscriptionAtRow:(int)indexPath.row]) {
//                // It's a single issue purchase
//                productImageView.backgroundColor = [UIColor colorWithHue:0.2111 saturation:0.87 brightness:0.61 alpha:1.0];
//            } else {
//                // It's a subscription
//                productImageView.backgroundColor = [UIColor colorWithHue:0.2111 saturation:0.87 brightness:0.76 alpha:1.0];
//            }
//        }
        
        UILabel *productPrice = (UILabel *)[cell viewWithTag:102];
        [_priceFormatter setLocale:product.priceLocale];
//        productPrice.text = [NSString stringWithFormat:@"$%0.2f",[product price].floatValue];
        productPrice.text = [_priceFormatter stringFromNumber:product.price];
        
        NSString *autoRenewingMonths = [self calculateAutoRenewingSubscriptionMonthsFromProduct:product];
        UILabel *productTitle = (UILabel *)[cell viewWithTag:101];
        UILabel *productDescription = (UILabel *)[cell viewWithTag:103];
        
        if (autoRenewingMonths) {
            productTitle.text = [NSString stringWithFormat:@"%@ month auto-renewing subscription", autoRenewingMonths];
            productDescription.text = [NSString stringWithFormat:@"A subscription to New Internationalist magazine that auto-renews every %@ months until you cancel it. This option includes a 1 month trial period so you can try before being billed, and if you continue you get an extra month free.", autoRenewingMonths];
        } else {
            productTitle.text = [product localizedTitle];
            productDescription.text = [product localizedDescription];
        }
        
        // Set fonts so it responds to Dynamic Type
        productTitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        productPrice.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        productDescription.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        
        if (purchased) {
            // Product has already been purchased
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.accessoryView = nil;
            cell.backgroundColor = [[self.navigationController.navigationBar tintColor] colorWithAlphaComponent:0.1]; // [UIColor colorWithRed:0.282 green:0.729 blue:0.714 alpha:0.5];
        } else {
//            productBuyButton.tag = indexPath.row;
            cell.backgroundColor = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    
    return cell;
}

- (NSString *)calculateAutoRenewingSubscriptionMonthsFromProduct:(SKProduct *)product
{
    if ([[product productIdentifier] rangeOfString:@"auto"].location == NSNotFound) {
        return nil;
    } else {
        // REGEX the first digit(s)
        NSError *regError;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\b\\d+" options:NSRegularExpressionCaseInsensitive error:&regError];
        if (regError) {
            DebugLog(@"Regex error: %@",regError.localizedDescription);
        }
        
        NSString *productID = [product productIdentifier];
        NSString *numberOfMonths = nil;
        NSRange range = [regex rangeOfFirstMatchInString:productID options:kNilOptions range:NSMakeRange(0, [productID length])];
        if(range.location != NSNotFound)
        {
            numberOfMonths = [productID substringWithRange:range];
        }
        
//        DebugLog(@"Number of months: %@", numberOfMonths);
        return numberOfMonths;
    }
}

- (CGSize)calculateCellSize:(UITableViewCell *)cell inTableView:(UITableView *)tableView {
    
    CGSize fittingSize = CGSizeMake(tableView.bounds.size.width, 0);
    CGSize size = [cell.contentView systemLayoutSizeFittingSize:fittingSize];
    
//    DebugLog(@"Cell: %@\nSize: %@", NSStringFromCGSize(cell.frame.size), NSStringFromCGSize(size));
    
    return size;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
    
    // It doesn't want to calculate correctly, so here's some magic
    float magicMultiplyer = 1.2;
    
    float cellHeight = [self calculateCellSize:cell inTableView:tableView].height;
    
    if (cellHeight * magicMultiplyer < [cell frame].size.height) {
        return [cell frame].size.height;
    } else {
        return cellHeight * magicMultiplyer;
    }
}

#pragma mark -
#pragma mark - Actions

- (IBAction)buyButtonTapped:(id)sender
{
    UIButton *buyButton = (UIButton *)sender;
    // iOS 7 changes the view hierarchy of the cell, use button frame to get the indexPath.
    CGRect buttonFrameInTableView = [buyButton convertRect:buyButton.bounds toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonFrameInTableView.origin];
    
    if ([self hasProductBeenPurchasedAtRow:(int)indexPath.row]) {
        // Product has been purchased, so do nothing
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"purchaseAlertTitle", nil)
                                    message:NSLocalizedString(@"purchaseAlertMessage", nil)
                                   delegate:self
                          cancelButtonTitle:NSLocalizedString(@"purchaseAlertButton", nil)
                          otherButtonTitles:nil] show];
    } else {
        [self purchaseProductAtRow:(int)indexPath.row];
    }
}

- (IBAction)restorePurchasesButtonTapped:(id)sender
{
    // TODO: Start restore animation/overlay
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"restoreAlertTitle", nil)
                                                                   message:NSLocalizedString(@"restoreAlertMessage", nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"restoreAlertButtonDefault", nil) style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              [[NIAUInAppPurchaseHelper sharedInstance] restoreCompletedTransactions];
                                                          }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"restoreAlertButtonCancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {}];
    
    [alert addAction:defaultAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self hasProductBeenPurchasedAtRow:(int)indexPath.row]) {
        if ([self isProductASubscriptionAtRow:(int)indexPath.row]) {
            // Subscription has been purchased, so do nothing
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"purchaseAlertTitle", nil)
                                        message:NSLocalizedString(@"purchaseAlertMessage", nil)
                                       delegate:self
                              cancelButtonTitle:NSLocalizedString(@"purchaseAlertButton", nil)
                              otherButtonTitles:nil] show];
        } else {
            // Magazine has been purchased, so go to that issue
            [self performSegueWithIdentifier:@"showTableOfContents" sender:self];
        }
        
    } else {
        // Product hasn't been purchased, so purchase it!
        [self purchaseProductAtRow:(int)indexPath.row];
    }
}

- (void)purchaseProductAtRow:(int)row
{
    SKProduct *product = _products[row];
    
    NSLog(@"Starting purchase: %@...", product.productIdentifier);
    [[NIAUInAppPurchaseHelper sharedInstance] buyProduct:product];
}

#pragma mark -
#pragma mark - SKPaymentTransactionObserver delegate methods

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    // TODO: Stop restore animation/overlay
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    // TODO: Handle any non-finished transactions?
    DebugLog(@"UpdatedTransactions: %@", transactions);
}

#pragma mark -
#pragma mark - Product helper methods

- (BOOL)hasProductBeenPurchasedAtRow:(int)row
{
    BOOL purchased = FALSE;
    if (_products) {
        SKProduct *product = _products[row];
        if ([[NIAUInAppPurchaseHelper sharedInstance] productPurchased:product.productIdentifier]) {
            purchased = TRUE;
            DebugLog(@"Magazine purchased from iTunes: %@", product.productIdentifier);
        }
        if (_railsUserInfo) {
            // Check to see if the user purchased an issue on rails
            NSArray *purchases = [_railsUserInfo objectForKey:@"purchases"];
            if (purchases && [purchases count] > 0) {
                for (NSNumber *issueNumber in purchases) {
                    if ([product.productIdentifier containsString:[issueNumber stringValue]]) {
                        purchased = TRUE;
                        DebugLog(@"Magazine purchased from Rails: %@", [issueNumber stringValue]);
                    }
                }
            }
        }
    }
    return purchased;
}

- (BOOL)isProductASubscriptionAtRow:(int)row
{
    if (_products) {
        SKProduct *product = _products[row];
        
        if ([[product productIdentifier] rangeOfString:@"month"].location == NSNotFound) {
            return FALSE;
        } else {
            return TRUE;
        }
    } else {
        return FALSE;
    }
}

#pragma mark -
#pragma mark - Rotation

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    DebugLog(@"TODO: Work out how to recalculate the cell height and then reload it.");
    
//    Not working!
    
//    for (int i = 0; i < self.tableView.indexPathsForVisibleRows.count; i++) {
//        [self tableView:self.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
//    }
    
//    [self.tableView reloadData];
}

#pragma mark - Dynamic Text

- (void)preferredContentSizeChanged:(NSNotification *)notification
{
    NSLog(@"Notification received for text change!");
    
    [self.tableView reloadData];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showTableOfContents"])
    {
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
        
        NIAUTableOfContentsViewController *tableOfContentsViewController = [segue destinationViewController];
        tableOfContentsViewController.issue = [self issueAtIndexPath:selectedIndexPath];
    }
    
}

- (NIAUIssue *)issueAtIndexPath: (NSIndexPath *)indexPath
{
    SKProduct *product = _products[indexPath.row];
    
    // Pull the number (issue name) out of the product identifier so we can get the Issue from Publisher
    NSString *issueNumber = [[product.productIdentifier componentsSeparatedByCharactersInSet:
                              [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                             componentsJoinedByString:@""];
    
    return [[NIAUPublisher getInstance] issueWithName:issueNumber];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/



@end
