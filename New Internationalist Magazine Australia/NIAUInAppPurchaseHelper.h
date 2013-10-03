//
//  NIAUInAppPurchaseManager.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 2/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

typedef void (^RequestProductsCompletionHandler)(BOOL success, NSArray * products);

@interface NIAUInAppPurchaseHelper : NSObject <SKProductsRequestDelegate>
{
    SKProductsRequest *_productsRequest;
    RequestProductsCompletionHandler _completionHandler;
    NSSet *_productIdentifiers;
    NSMutableSet *_purchasedProductIdentifiers;
}

- (id)initWithProductIdentifiers:(NSSet *)productIdentifiers;
- (void)requestProductsWithCompletionHandler:(RequestProductsCompletionHandler)completionHandler;

+ (NIAUInAppPurchaseHelper *)sharedInstance;

@end