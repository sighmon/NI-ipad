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
    
    // TODO: Possible race condition with sharedInstance being nil while dispatch_once is being called.
    
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
    
    [_purchasedProductIdentifiers addObject:productIdentifier];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:productIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductPurchasedNotification object:productIdentifier userInfo:nil];
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

@end