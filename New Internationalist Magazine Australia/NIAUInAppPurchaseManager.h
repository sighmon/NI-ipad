//
//  NIAUInAppPurchaseManager.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 2/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#define kInAppPurchaseManagerProductsFetchedNotification @"kInAppPurchaseManagerProductsFetchedNotification"

@interface NIAUInAppPurchaseManager : NSObject <SKProductsRequestDelegate>
{
    SKProduct *singleIssuePurchase;
    SKProductsRequest *productsRequest;
}

- (void)requestSingleIssuePurchaseProductData;

@end
