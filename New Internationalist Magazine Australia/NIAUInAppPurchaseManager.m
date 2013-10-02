//
//  NIAUInAppPurchaseManager.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 2/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUInAppPurchaseManager.h"

@implementation NIAUInAppPurchaseManager

- (void)requestSingleIssuePurchaseProductData
{
    // TODO: load productIdentifiers from JSON feed from the rails site.
    
    // TOFIX: manually coding the productIdentifier for testing.
    NSSet *productIdentifiers = [NSSet setWithObject:@"au.com.newint.nisingleissuepurchase" ];
    productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    productsRequest.delegate = self;
    [productsRequest start];
}

#pragma mark -
#pragma mark SKProductsRequestDelegate methods

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *products = response.products;
    singleIssuePurchase = [products count] == 1 ? [products firstObject] : nil;
    if (singleIssuePurchase)
    {
        NSLog(@"Product title: %@" , singleIssuePurchase.localizedTitle);
        NSLog(@"Product description: %@" , singleIssuePurchase.localizedDescription);
        NSLog(@"Product price: %@" , singleIssuePurchase.price);
        NSLog(@"Product id: %@" , singleIssuePurchase.productIdentifier);
    }
    
    for (NSString *invalidProductId in response.invalidProductIdentifiers)
    {
        NSLog(@"Invalid product id: %@" , invalidProductId);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kInAppPurchaseManagerProductsFetchedNotification object:self userInfo:nil];
}

@end
