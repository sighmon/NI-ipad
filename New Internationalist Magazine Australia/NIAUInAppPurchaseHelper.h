//
//  NIAUInAppPurchaseManager.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 2/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

// Following tutorial http://www.raywenderlich.com/21081/introduction-to-in-app-purchases-in-ios-6-tutorial

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <SSZipArchive.h>
#import "NIAUPublisher.h"

#import "GAI.h"
#import "GAITracker.h"
#import "GAITrackedViewController.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "GAILogger.h"

typedef void (^RequestProductsCompletionHandler)(BOOL success, NSArray * products);
UIKIT_EXTERN NSString *const IAPHelperProductPurchasedNotification;

@interface NIAUInAppPurchaseHelper : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver, NSURLConnectionDelegate, SSZipArchiveDelegate>
{
    SKProductsRequest *_productsRequest;
    RequestProductsCompletionHandler _completionHandler;
    NSSet *_productIdentifiers;
    NSMutableSet *_purchasedProductIdentifiers;
    NSMutableData *receivedData;
    BOOL iTunesSandboxRequest;
}

@property (nonatomic, strong) NSArray *allProducts;

- (id)initWithProductIdentifiers:(NSSet *)productIdentifiers;
- (void)requestProductsWithCompletionHandler:(RequestProductsCompletionHandler)completionHandler;

- (void)buyProduct:(SKProduct *)product;
- (BOOL)productPurchased:(NSString *)productIdentifier;

- (void)restoreCompletedTransactions;

+ (NSData *)getUserExpiryDateFromRailsAndAppStoreReceipt;

+ (NIAUInAppPurchaseHelper *)sharedInstance;

+ (NIAUInAppPurchaseHelper *)validateReceiptWithData:(NSData *)receiptData completionHandler:(void(^)(BOOL,NSString *))handler;

@property (nonatomic,strong) void(^completionBlock)(BOOL,NSString *);
@property (nonatomic,strong) NSData *receiptData;

-(void)checkReceipt;

- (void)unzipAndMoveFilesForIssue:(NKIssue *)issue toDestinationURL:(NSURL *)destinationURL;
- (NSString *)requestZipURLforRailsID: (NSString *)railsID;

@end
