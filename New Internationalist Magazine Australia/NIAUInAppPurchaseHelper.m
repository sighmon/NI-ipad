//
//  NIAUInAppPurchaseManager.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 2/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUInAppPurchaseHelper.h"
#import "NSData+Cookieless.h"
#import "local.h"

NSString *const IAPHelperProductPurchasedNotification = @"IAPHelperProductPurchasedNotification";

@implementation NIAUInAppPurchaseHelper
{
    BOOL moveSuccess;
}

- (id)initWithProductIdentifiers:(NSSet *)productIdentifiers {
    
    if ((self = [super init])) {
        
        // Store product identifiers
        _productIdentifiers = productIdentifiers;
        
        self.allProducts = @[];
        
        // Check for previously purchased products
        _purchasedProductIdentifiers = [NSMutableSet set];
        for (NSString *productIdentifier in _productIdentifiers) {
            BOOL productPurchased = [[NSUserDefaults standardUserDefaults] boolForKey:productIdentifier];
            if (productPurchased) {
                [_purchasedProductIdentifiers addObject:productIdentifier];
                NSLog(@"Previously purchased: %@", productIdentifier);
            } else {
//                NSLog(@"Not purchased: %@", productIdentifier);
            }
        }
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)requestProductsWithCompletionHandler:(RequestProductsCompletionHandler)completionHandler {
    
    _completionHandler = [completionHandler copy];
    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _productsRequest.delegate = self;
    [_productsRequest start];
    
}

+ (NIAUInAppPurchaseHelper *)sharedInstance {
    
    // Possible race condition with sharedInstance being nil while dispatch_once is being called.
    
    static dispatch_once_t once;
    static NIAUInAppPurchaseHelper *sharedInstance;
    dispatch_once(&once, ^{
        // Pull productIdentifiers from a JSON feed.
        NSError *error;
        NSURL *jsonURL = [NSURL URLWithString:@"newsstand.json" relativeToURL:[NSURL URLWithString:SITE_URL]];
        NSData *data = [NSData dataWithContentsOfCookielessURL:jsonURL];
//        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
        if (data) {
            NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            
            NSSet *subscriptionsSet = [NSSet setWithArray:jsonDictionary[@"subscriptions"]];
            NSSet *issuesSet = [NSSet setWithArray:jsonDictionary[@"issues"]];
            NSSet *productIdentifiers = [subscriptionsSet setByAddingObjectsFromSet:issuesSet];
            sharedInstance = [[self alloc] initWithProductIdentifiers:productIdentifiers];
        }
    });
    return sharedInstance;
}

#pragma mark -
#pragma mark - Purchasing a product

- (BOOL)productPurchased:(NSString *)productIdentifier {
    return [_purchasedProductIdentifiers containsObject:productIdentifier];
}

- (void)buyProduct:(SKProduct *)product {
    
    NSLog(@"Buying %@...", product.productIdentifier);
    
    SKPayment * payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
}

#pragma mark -
#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction * transaction in transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    };
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"completeTransaction...");
    
    [self provideContentForProductIdentifier:transaction.payment.productIdentifier];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    [self sendReceiptToRails];
    [self sendGoogleAnalyticsStatsForTransaction:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"restoreTransaction: %@", transaction.originalTransaction.payment.productIdentifier);
    
    [self provideContentForProductIdentifier:transaction.originalTransaction.payment.productIdentifier];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    [self sendReceiptToRails];
    [self sendGoogleAnalyticsStatsForTransaction:transaction];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
    NSLog(@"failedTransaction...");
    if (transaction.error.code != SKErrorPaymentCancelled)
    {
        NSLog(@"Transaction error: %@", transaction.error.localizedDescription);
        [self sendGoogleAnalyticsStatsForTransaction:transaction];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier {
    
    if (productIdentifier) {
        [_purchasedProductIdentifiers addObject:productIdentifier];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:productIdentifier];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductPurchasedNotification object:productIdentifier userInfo:nil];
    } else {
        NSLog(@"ERROR - no product identifier: %@", productIdentifier);
    }
}

- (void)restoreCompletedTransactions {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    
    // TODO: Add code to the Products UI to handle restoring purchases after an app has been deleted, or syncing across devices.
}

- (void)sendGoogleAnalyticsStatsForTransaction:(SKPaymentTransaction *)transaction
{
    // Send Transaction Analytics
    
    // Find the product being purchased
    SKProduct *productBeingPurchased;
    NSString *productCategory = @"";
    NSUInteger productIndex = [self.allProducts indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        if ([[(SKProduct *)obj productIdentifier] isEqualToString:transaction.payment.productIdentifier]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    if (productIndex != NSNotFound) {
        productBeingPurchased = self.allProducts[productIndex];
    }
    if ([productBeingPurchased.productIdentifier rangeOfString:@"single"].location == NSNotFound) {
        productCategory = @"Subscription";
    } else {
        productCategory = @"Magazine";
    }
    
    [[GAI sharedInstance].defaultTracker send:[[GAIDictionaryBuilder createTransactionWithId:transaction.transactionIdentifier
                                                                                 affiliation:@"In-app Purchase"
                                                                                     revenue:productBeingPurchased.price
                                                                                         tax:[NSNumber numberWithDouble:(productBeingPurchased.price.floatValue/10.)]
                                                                                    shipping:@0
                                                                                currencyCode:@"AUD"] build]];
    
    
    [[GAI sharedInstance].defaultTracker send:[[GAIDictionaryBuilder createItemWithTransactionId:transaction.transactionIdentifier
                                                                                            name:productBeingPurchased.localizedTitle
                                                                                             sku:productBeingPurchased.productIdentifier
                                                                                        category:productCategory
                                                                                           price:productBeingPurchased.price
                                                                                        quantity:@1
                                                                                    currencyCode:@"AUD"] build]];
    
    [[GAI sharedInstance].defaultTracker send:[[GAIDictionaryBuilder createEventWithCategory:productCategory
                                                                                      action:@"Purchase"
                                                                                       label:@"ios"
                                                                                       value:productBeingPurchased.price] build]];
}

- (void)sendReceiptToRails
{
    // TODO: Send the receipt to rails for validation with iTunes and syncing with the user's subscription
    
    // TODO: Check if the user is logged in, and only send the data if they are.
    
//    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
//    
//    NSString *postString = [[NSString alloc] initWithData:receiptData encoding:NSUTF8StringEncoding];
//    NSData *postData = [postString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
//    NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
//    
//    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
//    [request setURL:[NSURL URLWithString:@"http://10.0.1.102:3000/users"]];
//    [request setHTTPMethod:@"POST"];
//    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
//    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
//    [request setHTTPBody:postData];
//    
//    // TODO: Add in username to the request
//    
//    NSError *error;
//    NSURLResponse *response;
//    NSData *urlData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//    NSString *data = [[NSString alloc]initWithData:urlData encoding:NSUTF8StringEncoding];
//    if (!error) {
//        NSLog(@"Response from Rails: %@", data);
//    } else {
//        NSLog(@"Rails returned an error: %@\nAnd data: %@", error, data);
//    }
}

#pragma mark -
#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
    NSLog(@"Loaded list of products...");
    _productsRequest = nil;
    
    self.allProducts = response.products;
    NSMutableArray *skProducts = [NSMutableArray arrayWithArray:response.products];
    
    NSMutableArray *justSubscriptions = [NSMutableArray array];
    NSMutableArray *justIssues = [NSMutableArray array];
    
    for (SKProduct *skProduct in skProducts) {
        // Separate the subscriptions & individual issues
        if ([skProduct.productIdentifier rangeOfString:@"single"].location == NSNotFound) {
            [justSubscriptions addObject:skProduct];
        } else {
            [justIssues addObject:skProduct];
        }
    }
    
    // Remove all products and add them back with the issues sorted by productIdentifier
    NSSortDescriptor *lowestIdentifierToHighest = [NSSortDescriptor sortDescriptorWithKey:@"productIdentifier" ascending:NO];
    [skProducts removeAllObjects];
    [skProducts addObjectsFromArray:justSubscriptions];
    [skProducts addObjectsFromArray:[justIssues sortedArrayUsingDescriptors:[NSArray arrayWithObject:lowestIdentifierToHighest]]];
    justIssues = nil;
    justSubscriptions = nil;
    
//    for (SKProduct *skProduct in skProducts) {
//        NSLog(@"Found product: %@ %@ %0.2f",
//              skProduct.productIdentifier,
//              skProduct.localizedTitle,
//              skProduct.price.floatValue);
//    }
    
    _completionHandler(YES, skProducts);
    _completionHandler = nil;
    
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    
    NSLog(@"Failed to load list of products: %@", error);
    _productsRequest = nil;
    
    _completionHandler(NO, nil);
    _completionHandler = nil;
    
}

+ (NSData *)getUserExpiryDateFromRailsAndAppStoreReceipt
{
    // POSTs the receipt to Rails, and then onto iTunes to check for a valid subscription
    // Returns either the rails expiry date or app store expiry date.
    
    // NOTE: user id will be ignored and current_user information will be returned by rails.
    NSURL *userURL = [NSURL URLWithString:[NSString stringWithFormat:@"users/1.json"] relativeToURL:[NSURL URLWithString:SITE_URL]];
    
    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    
    NSString *base64receipt = [receiptData base64EncodedStringWithOptions:0];
    NSData *postData = [base64receipt dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%d", (int)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:userURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    NSError *error;
    NSHTTPURLResponse *response;
    
    //    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    int statusCode = (int)[response statusCode];
    NSString *data = [[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding];
    if (!error && statusCode >= 200 && statusCode < 300) {
        //        NSLog(@"Response from Rails: %@", data);
        if ([[[response URL] lastPathComponent] isEqualToString:@"sign_in"]) {
            // User isn't logged in, or login was wrong
            NSLog(@"Rails response: Redirected to sign_in");
            responseData = nil;
        }
    } else {
        NSLog(@"Rails returned statusCode: %d\n an error: %@\nAnd data: %@", statusCode, error, data);
        responseData = nil;
    }
    
    return responseData;
}

+ (NIAUInAppPurchaseHelper *)validateReceiptWithData:(NSData *)_receiptData completionHandler:(void(^)(BOOL,NSString *))handler {
    NIAUInAppPurchaseHelper *checker = [[NIAUInAppPurchaseHelper alloc] init];
    checker.receiptData = _receiptData;
    checker.completionBlock = handler;
    [checker checkReceipt];
    return checker;
    
}

- (void)checkReceipt {
    // verifies receipt with Apple
    NSError *jsonError = nil;
    NSString *receiptBase64 = [self.receiptData base64EncodedStringWithOptions:0];
//    NSLog(@"Receipt Base64: %@",receiptBase64);
    //NSString *jsonRequest=[NSString stringWithFormat:@"{\"receipt-data\":\"%@\"}",receiptBase64];
    //NSLog(@"Sending this JSON: %@",jsonRequest);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                receiptBase64,@"receipt-data",
                                                                ITUNES_SECRET,@"password",
                                                                nil]
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&jsonError
                        ];
//    NSLog(@"JSON: %@",[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    
    // URL for sandbox receipt validation; replace "sandbox" with "buy" in production or you will receive
    // error codes 21006 or 21007
//    NSURL *requestURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    NSURL *requestURL = [NSURL URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"];
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:requestURL];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:jsonData];
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:req delegate:self];
    if(conn) {
        receivedData = [[NSMutableData alloc] init];
    } else {
        self.completionBlock(NO,@"Cannot create connection");
    }
}

#pragma mark - Zip and move

- (void)unzipAndMoveFilesForConnection:(NSURLConnection *)connection toDestinationURL:(NSURL *)destinationURL
{
    NKAssetDownload *download = connection.newsstandAssetDownload;
    NKIssue *nkIssue = download.issue;
    
    // Unzip the downloaded file
    BOOL zipSuccess = NO;
    //    NSString *zipPath = [[NIAUPublisher getInstance] downloadPathForIssue:nkIssue];
    NSString *contentPath = [[[nkIssue contentURL] path] stringByAppendingString:@"/"];
    NSString *zipPath = [destinationURL path];
    NSString *unZippedPath = [[[destinationURL path] stringByDeletingLastPathComponent] stringByAppendingString:@"/temp/"];
    NSError *zipError;
    
    zipSuccess = [SSZipArchive unzipFileAtPath:zipPath toDestination:unZippedPath overwrite:NO password:nil error:&zipError];
    if (!zipSuccess || zipError){
        // Handle this
        NSLog(@"Zip error: %@", zipError);
    } else {
        NSLog(@"Unzip succedded.");
        // Delete zip file
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:zipPath error: &error];
        if (error) {
            NSLog(@"ERROR: Zip file couldn't be deleted from: %@", zipPath);
        } else {
            NSLog(@"Zip file deleted from: %@", zipPath);
        }
    }
    
    // Loop through the temp directory and copy files to destination URL
    NSError *filesError = nil;
    moveSuccess = false;
    
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:unZippedPath error:&filesError];
    if (files == nil || filesError) {
        // Error
        NSLog(@"Error making the array from temp files in zip: %@", filesError);
    }
    
    for (NSString *file in files) {
        
        NSString *filePath = [unZippedPath stringByAppendingString:file];
        NSString *destinationPath = [contentPath stringByAppendingString:file];
        
        // Checking to see if any of the files is a directory
        
        if (([file rangeOfString:@"."].location == NSNotFound)) {
            // file is a directory
            NSArray *subDirectoryfiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[unZippedPath stringByAppendingString:file] error:&filesError];
            for (NSString *subDirFile in subDirectoryfiles) {
                // Move this sub-directory file
                NSString *tempFilePath = [filePath stringByAppendingString:[NSString stringWithFormat:@"/%@",subDirFile]];
                NSString *tempDestinationPath = [destinationPath stringByAppendingString:[NSString stringWithFormat:@"/%@",subDirFile]];
                [self moveFile:tempFilePath toDestination:tempDestinationPath];
            }
        } else {
            // Move this base-directory file
            [self moveFile:filePath toDestination:destinationPath];
        }
    }
    
    // Delete the temp directory.
    if ([[NSFileManager defaultManager] fileExistsAtPath:unZippedPath]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:unZippedPath error: &error];
        if (error) {
            NSLog(@"ERROR: unzipped path couldn't be deleted from: %@", unZippedPath);
        } else {
            NSLog(@"Unzipped path deleted from: %@", unZippedPath);
        }
    }
    
    if (moveSuccess) {
        // Force a refresh
        [[NIAUPublisher getInstance] forceDownloadIssues];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshViewNotification" object:nil];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download complete" message:@"The latest issue of New Internationalist has been downloaded and is ready to read." delegate:self cancelButtonTitle:@"Thanks!" otherButtonTitles:nil];
        [alert show];
        alert.delegate = nil;
    } else {
        NSLog(@"ERROR: Nothing was moved, so either the user already had the entire issue in cache, or something went wrong.");
    }
}

- (BOOL)moveFile:(NSString *)filePath toDestination:(NSString *)destinationPath
{
    NSError *moveError = nil;
    if([[NSFileManager defaultManager] moveItemAtPath:filePath toPath:destinationPath error:&moveError]==NO) {
        NSLog(@"Error moving file from %@ to %@", filePath, destinationPath);
        return NO;
    } else {
        NSLog(@"File moved from %@ to %@", filePath, destinationPath);
        moveSuccess = true;
        return YES;
    }
}

- (NSString *)requestZipURLforRailsID: (NSString *)railsID
{
    // get zipURL from Rails
    NSURL *issueURL = [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@.json", railsID] relativeToURL:[NSURL URLWithString:SITE_URL]];
    
    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    
    NSString *base64receipt = [receiptData base64EncodedStringWithOptions:0];
    NSData *postData = [base64receipt dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%d", (int)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:issueURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    NSError *error;
    NSHTTPURLResponse *response;
    
    //    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    int statusCode = (int)[response statusCode];
    NSString *data = [[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding];
    if (!error && statusCode >= 200 && statusCode < 300) {
        //        NSLog(@"Response from Rails: %@", data);
        if ([[[response URL] lastPathComponent] isEqualToString:@"issues"]) {
            // Issue isn't published yet.
            NSLog(@"Rails response: Redirected to /issues");
            responseData = nil;
        }
    } else {
        NSLog(@"Rails returned statusCode: %d\n an error: %@\nAnd data: %@", statusCode, error, data);
        responseData = nil;
    }
    
    if (responseData) {
        NSError *error = nil;
        NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:&error];
        
        if (error != nil) {
            NSLog(@"Error parsing JSON.");
        }
        else {
            // Got a response from Rails, display it.
            NSLog(@"JSON: %@", jsonDictionary);
            if ([jsonDictionary objectForKey:@"zipURL"] != [NSNull null]) {
                // return URL
                return [jsonDictionary objectForKey:@"zipURL"];
            }
        }
    }
    return nil;
}

#pragma mark - Connection delegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Cannot transmit receipt data. %@",[error localizedDescription]);
    self.completionBlock(NO,[error localizedDescription]);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *response = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
//    NSLog(@"iTunes response: %@",response);
    self.completionBlock(YES,response);
}

@end