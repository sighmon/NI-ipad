//
//  NIAUAppDelegate.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 20/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUAppDelegate.h"

#import "NIAUViewController.h"
#import "NIAUInAppPurchaseHelper.h"
#import "local.h"
#import "NIAUPublisher.h"
#import "NIAUArticleViewController.h"
#import "NIAUTableOfContentsViewController.h"
#import "NIAUCategoryViewController.h"
#import "NIAUCategoriesViewController.h"
#import "NIAUIssue.h"
#import <objc/runtime.h>
const char NotificationKey;

#import "GAI.h"
#import "GAITracker.h"
#import "GAITrackedViewController.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "GAILogger.h"

#import "TAGContainer.h"
#import "TAGContainerOpener.h"
#import "TAGManager.h"

#import <Crashlytics/Crashlytics.h>

@interface NIAUAppDelegate () <TAGContainerOpenerNotifier>
@end

@implementation NIAUAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    BOOL firstRun = false;
    
    // Load the In App Purchase Helper at launch to check for unfinished purchases.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [NIAUInAppPurchaseHelper sharedInstance];
    });
        
    // Push notification tracking analytics
    if (application.applicationState != UIApplicationStateBackground) {
        // Track an app open here if we launch with a push, unless
        // "content_available" was used to trigger a background push (introduced
        // in iOS 7). In that case, we skip tracking here to avoid double counting
        // the app-open.
        BOOL preBackgroundPush = ![application respondsToSelector:@selector(backgroundRefreshStatus)];
        BOOL oldPushHandlerOnly = ![self respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)];
        BOOL noPushPayload = ![launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (preBackgroundPush || oldPushHandlerOnly || noPushPayload) {
            // TODO: Still track opens now that Parse is removed?
//            [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
        }
    }
    
    // Setup app to receive UIRemoteNotifications
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert |
         UIUserNotificationTypeBadge |
         UIUserNotificationTypeSound
                                          categories:nil];
        [application registerUserNotificationSettings:settings];
        [application registerForRemoteNotifications];
    } else {
        // iOS 7.x - which we're no longer targeting.
    }
    
    // Get User Defaults.
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    // Remove this for launch - allows multiple NewsStand notifications. :-)
//    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NKDontThrottleNewsstandContentNotifications"];
    
    // When we receive a Remote Notification, grab the issue number from the payload and download it.
    NSDictionary *payload = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if(payload) {        
        // This only fires if the application is launched from a remote notification by the user
        // Also fires when the newsstand content-available starts the app in the background.
        
        // TODO: Think this is double handling... 13th Aug 2014
        // Going to leave it out for now, seeing as I'm not sending content-available notifications now anyway.
//        DebugLog(@"Opened from the push notification!");
//        [self handleRemoteNotification:application andUserInfo:payload];
    }
    
    // Google Analytics
    
    // Optional: automatically send uncaught exceptions to Google Analytics.
//    [GAI sharedInstance].trackUncaughtExceptions = YES;
    [GAI sharedInstance].trackUncaughtExceptions = NO;
    
    // Optional: set Google Analytics dispatch interval to e.g. 20 seconds.
    [GAI sharedInstance].dispatchInterval = 20;
    
    // Optional: set Logger to VERBOSE for debug information.
//    [[[GAI sharedInstance] logger] setLogLevel:kGAILogLevelVerbose];
    
    // Initialize tracker.
    id<GAITracker> tracker = [[GAI sharedInstance] trackerWithTrackingId:GOOGLE_ANALYTICS_ID];
    DebugLog(@"Google Analytics tracker initialized: %@", tracker);
    
    // If user hasn't set a default, set it to TRUE
    if ([standardUserDefaults objectForKey:@"googleAnalytics"] == nil) {
        [standardUserDefaults setBool:TRUE forKey:@"googleAnalytics"];
        [standardUserDefaults synchronize];
        firstRun = true;
    } else if ([standardUserDefaults boolForKey:@"googleAnalytics"] == 0) {
        // User has asked to opt-out of Google Analytics
        [[GAI sharedInstance] setOptOut:YES];
    }
    
    // For first run, set show help to TRUE
    if ([standardUserDefaults objectForKey:@"showHelp"] == nil) {
        [standardUserDefaults setBool:TRUE forKey:@"showHelp"];
        [standardUserDefaults synchronize];
    } else if ([standardUserDefaults boolForKey:@"showHelp"] == 0) {
        // User has asked not to display help anymore.
        DebugLog(@"Help disabled (at app delegate).");
    }
    
    // If user says analytics are okay, load Google Tag Manager
    if ([standardUserDefaults boolForKey:@"googleAnalytics"] == 1) {

        // Google Tag Manager
        self.tagManager = [TAGManager instance];
        
        // Optional: Change the LogLevel to Verbose to enable logging at VERBOSE and higher levels.
        [self.tagManager.logger setLogLevel:kTAGLoggerLogLevelVerbose];
        
        /*
         * Opens a container.
         *
         * @param containerId The ID of the container to load.
         * @param tagManager The TAGManager instance for getting the container.
         * @param openType The choice of how to open the container.
         * @param timeout The timeout period (default is 2.0 seconds).
         * @param notifier The notifier to inform on container load events.
         */
        [TAGContainerOpener openContainerWithId:GOOGLE_TAG_MANAGER_ID
                                     tagManager:self.tagManager
                                       openType:kTAGOpenTypePreferFresh
                                        timeout:nil
                                       notifier:self];
    }
    
    // For first run, set Big Images to TRUE
    if ([standardUserDefaults objectForKey:@"bigImages"] == nil) {
        [standardUserDefaults setBool:TRUE forKey:@"bigImages"];
        [standardUserDefaults synchronize];
    }
    
    // Crashlytics - only load if user hasn't opted out of analytics
    if ([standardUserDefaults boolForKey:@"googleAnalytics"] == 1) {
        // Okay to load Crashlytics
        [Crashlytics startWithAPIKey:CRASHLYTICS_API_KEY];
    }
    
    // Update sharedUserDefaults
    [NIAUHelper updateSharedUserDefaults];
    
    // Send install stat to analytics
    if (firstRun && [standardUserDefaults boolForKey:@"googleAnalytics"] == 1) {
        TAGDataLayer *dataLayer = [TAGManager instance].dataLayer;
        
        [dataLayer push:@{@"event": @"install", @"label": @"iOS"}];
        DebugLog(@"Fresh install analytics sent");
    }
    
    // Override point for customization after application launch.
    return YES;
}

// TAGContainerOpenerNotifier callback.
- (void)containerAvailable:(TAGContainer *)container {
    // Note that containerAvailable may be called on any thread, so you may need to dispatch back to
    // your main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        self.container = container;
    });
}

#pragma mark - URL open handling

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    // Launched from a link newint://issues/id/articles/id
    
    BOOL URLIncludesNewint = false;
    BOOL articleOkayToLoad = false;
    BOOL issueOkayToLoad = false;
    BOOL categoryOkayToLoad = false;
    BOOL categoriesOkayToLoad = false;
    
    URLIncludesNewint = [[url absoluteString] hasPrefix:@"newint"];
    articleOkayToLoad = [NIAUHelper validArticleInURL:url];
    issueOkayToLoad = [NIAUHelper validIssueInURL:url];
    categoryOkayToLoad = [NIAUHelper validCategoryInURL:url];
    categoriesOkayToLoad = [NIAUHelper validCategoriesInURL:url];
    
    if (articleOkayToLoad) {
        // It's probably a good link, so let's load it.
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:[NSBundle mainBundle]];
        
        NIAUArticleViewController *articleViewController = [storyboard instantiateViewControllerWithIdentifier:@"article"];
        NIAUTableOfContentsViewController *issueViewController = [storyboard instantiateViewControllerWithIdentifier:@"issue"];
        
        NSString *articleIDFromURL = [[url pathComponents] lastObject];
        NSNumber *articleID = [NSNumber numberWithInt:(int)[articleIDFromURL integerValue]];
        NSString *issueIDFromURL = [[url pathComponents] objectAtIndex:1];
        NSNumber *issueID = [NSNumber numberWithInt:(int)[issueIDFromURL integerValue]];
        NSArray *arrayOfIssues = [NIAUIssue issuesFromNKLibrary];
        NSUInteger issueIndexPath = [arrayOfIssues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return ([[obj railsID] isEqualToNumber:issueID]);
        }];
        if (issueIndexPath != NSNotFound) {
            NIAUIssue *issue = [arrayOfIssues objectAtIndex:issueIndexPath];
            [issue forceDownloadArticles];
            issueViewController.issue = issue;
            
            NIAUArticle *articleToLoad = [issue articleWithRailsID:articleID];
            if (articleToLoad) {
                articleViewController.article = articleToLoad;
                [(UINavigationController *)self.window.rootViewController pushViewController:issueViewController animated:NO];
                [(UINavigationController *)self.window.rootViewController pushViewController:articleViewController animated:YES];
                
                return YES;
            } else {
                // Can't find the article, so let's just push the issue.
                [(UINavigationController *)self.window.rootViewController pushViewController:issueViewController animated:YES];
                return YES;
            }
        } else {
            // Can't find that issue..
            return NO;
        }
        
    } else if (issueOkayToLoad) {
        // Load the issue
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:[NSBundle mainBundle]];
        
        NIAUTableOfContentsViewController *issueViewController = [storyboard instantiateViewControllerWithIdentifier:@"issue"];
        NSString *issueIDFromURL = [[url pathComponents] objectAtIndex:1];
        NSNumber *issueID = [NSNumber numberWithInt:(int)[issueIDFromURL integerValue]];
        NSArray *arrayOfIssues = [NIAUIssue issuesFromNKLibrary];
        NSUInteger issueIndexPath = [arrayOfIssues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return ([[obj railsID] isEqualToNumber:issueID]);
        }];
        if (issueIndexPath != NSNotFound) {
            NIAUIssue *issue = [arrayOfIssues objectAtIndex:issueIndexPath];
            issueViewController.issue = issue;
            [(UINavigationController *)self.window.rootViewController pushViewController:issueViewController animated:YES];
            
            return YES;
        } else {
            // Can't find that issue..
            return NO;
        }
        
    } else if (categoryOkayToLoad) {
        // Load the category
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:[NSBundle mainBundle]];
        
        NIAUCategoryViewController *categoryViewController = [storyboard instantiateViewControllerWithIdentifier:@"category"];
        NSString *categoryIDFromURL = [[url pathComponents] objectAtIndex:1];
        NSNumber *categoryID = [NSNumber numberWithInt:(int)[categoryIDFromURL integerValue]];
        categoryViewController.categoryID = categoryID;
        
        [(UINavigationController *)self.window.rootViewController pushViewController:categoryViewController animated:YES];
        
        return YES;
        
        // TODO: Build an NIAUCategory model to clean this up.
        // TODO: Find category by categoryID
        
    } else if (categoriesOkayToLoad) {
        // Load categories view controller
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:[NSBundle mainBundle]];
        
        NIAUCategoriesViewController *categoriesViewController = [storyboard instantiateViewControllerWithIdentifier:@"categories"];
        [(UINavigationController *)self.window.rootViewController pushViewController:categoriesViewController animated:YES];
        return YES;
    
    } else if (URLIncludesNewint && ([url pathComponents] == nil)) {
        // Just open the app to the home view.
        return NO;
    } else {
        // Malformed link, so ignore it and just start the app.
        [[[UIAlertView alloc] initWithTitle:@"Sorry!" message:@"We don't recognise that link that you tried to open." delegate:self cancelButtonTitle:@"Okay." otherButtonTitles: nil] show];
        return NO;
    }
}

#pragma mark - Push notification setup

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    //  Save your token in userSettings so you can see it for debugging if need be.
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:deviceToken forKey:@"deviceToken"];
    
    DebugLog(@"Push notification deviceToken: %@", deviceToken);
    
    // Push the deviceToken to our NI server for push notifications
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *siteURLString = @"";
    if (DEBUG) {
        siteURLString = DEBUG_SITE_URL;
    } else {
        siteURLString = SITE_URL;
    }
    DebugLog(@"Push registrations URL: %@", siteURLString);
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"push_registrations"] relativeToURL:[NSURL URLWithString:siteURLString]]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSData *postData = [[NSString stringWithFormat:@"token=%@&device=%@", deviceToken, @"ios"] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *postLength = [NSString stringWithFormat:@"%d", (int)[postData length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:postData];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError)
    {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        int statusCode = (int)[httpResponse statusCode];
        if (statusCode >= 200 && statusCode < 300) {
            // Push registrations successful
            DebugLog(@"Status: %d. Push registrations was successful.", statusCode);
        } else {
            // Connection error with the Rails server
            DebugLog(@"ERROR sending push registration to Rails: %d", statusCode);
        }
    }];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    if ((application.applicationState == UIApplicationStateInactive) || (application.applicationState == UIApplicationStateBackground)) {
        // TODO: Track the push notification opens?
        [self turnBadgeIconOn];
        [self handleRemoteNotification:application andUserInfo:userInfo];
    } else {
        [self handleNotification:userInfo];
        // TODO: Track the push notification opens when the app is open?
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if ((application.applicationState == UIApplicationStateInactive) || (application.applicationState == UIApplicationStateBackground)) {
        // TODO: Track the push notification opens?
        [self turnBadgeIconOn];
        [self handleRemoteNotification:application andUserInfo:userInfo];
    } else {
        [self handleNotification:userInfo];
    }
}

- (void)handleRemoteNotification: (UIApplication *)application andUserInfo: (NSDictionary *)userInfo
{
    // Check userInfo to see if the notification is about a new issue, or a specific article
    
    if ([self isArticleIdIncludedInUserInfo: userInfo]) {
        // It's a specific article, open it
        
        NSURL *urlFromUserInfo = [NSURL URLWithString:[NSString stringWithFormat:@"newint://issues/%@/articles/%@", [userInfo objectForKey:@"issueID"], [userInfo objectForKey:@"articleID"]]];
        
        [self application:application handleOpenURL:urlFromUserInfo];
        
    } else {
        // It's an issue ready for download
        // Start background download.
        [self startBackgroundDownloadWithUserInfo:userInfo];
        
        UILocalNotification *localNotif = [[UILocalNotification alloc] init];
        if (localNotif) {
            localNotif.alertBody = [NSString stringWithFormat:
                                    NSLocalizedString(@"%@", nil), [[userInfo objectForKey:@"aps"] objectForKey:@"alert"]];
            localNotif.alertAction = NSLocalizedString(@"Read it now.", nil);
            localNotif.soundName = [NSString stringWithFormat:
                                    NSLocalizedString(@"%@", nil), [[userInfo objectForKey:@"aps"] objectForKey:@"sound"]];
            localNotif.applicationIconBadgeNumber = [[[userInfo objectForKey:@"aps"] objectForKey:@"badge"] intValue];
            [application presentLocalNotificationNow:localNotif];
        }
    }
}

- (void)handleNotification: (NSDictionary *)userInfo
{
    // Check userInfo to see if the notification is about a new issue, or a specific article
    
    if ([self isArticleIdIncludedInUserInfo: userInfo]) {
        // It's a specific article, ask if they want to open it
        NSString *message = [NSString stringWithFormat:@"%@ Would you like to read it now?", [[userInfo objectForKey:@"aps"] objectForKey:@"alert"]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Have you read..." message:message delegate:self cancelButtonTitle:@"Not now." otherButtonTitles:@"Read it now.", nil];
        [alert show];
        objc_setAssociatedObject(alert, &NotificationKey, userInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
    } else {
        // It's an issue ready for download
        // Ask the user whether they want to download the new issue now
        NSString *message = [NSString stringWithFormat:@"%@ Would you like to download it now in the background?", [[userInfo objectForKey:@"aps"] objectForKey:@"alert"]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New issue available" message:message delegate:self cancelButtonTitle:@"Not now." otherButtonTitles:@"Download", nil];
        [alert show];
        objc_setAssociatedObject(alert, &NotificationKey, userInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (BOOL)isArticleIdIncludedInUserInfo: (NSDictionary *)userInfo
{
    if (userInfo && [userInfo objectForKey:@"articleID"]) {
        return YES;
    } else {
        return NO;
    }
}

- (void)turnBadgeIconOn
{
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 1];
}

- (void)startBackgroundDownloadWithUserInfo: (NSDictionary *)userInfo
{
    // Get zip file from Rails, unpack it and save it to the library as a new nkIssue.
    
    if (userInfo) {
        // Get the zipURL from Rails.
        NSString *railsID = [userInfo objectForKey:@"railsID"];
        NSString *zipURL = [[NIAUInAppPurchaseHelper sharedInstance] requestZipURLforRailsID: railsID];
        
        if (zipURL) {
            // Create NIAUIssue from userInfo
            NIAUIssue *newIssue = [NIAUIssue issueWithUserInfo:userInfo];
            
            if (newIssue) {
                // schedule for issue downloading in background
                NKIssue *newNKIssue = [[NKLibrary sharedLibrary] issueWithName:newIssue.name];
                if (newNKIssue) {
                    NSURL *downloadURL = [NSURL URLWithString:zipURL];
                    NSURLRequest *req = [NSURLRequest requestWithURL:downloadURL];
                    NKAssetDownload *assetDownload = [newNKIssue addAssetWithRequest:req];
                    [assetDownload downloadWithDelegate:self];
                }
            } else {
                NSLog(@"New Issue couldn't be created from userInfo: %@", userInfo);
            }
            
        } else {
            NSLog(@"No zipURL, so aborting.");
        }
    } else {
        NSLog(@"No userInfo: %@", userInfo);
    }
}

#pragma mark AlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSDictionary *userInfo = objc_getAssociatedObject(alertView, &NotificationKey);
    
    switch (buttonIndex) {
        case 0:
            // Cancel pressed
            break;
        case 1:
            if ([self isArticleIdIncludedInUserInfo: userInfo]) {
                // Read article pressed
                NSURL *urlFromUserInfo = [NSURL URLWithString:[NSString stringWithFormat:@"newint://issues/%@/articles/%@", [userInfo objectForKey:@"issueID"], [userInfo objectForKey:@"articleID"]]];
                
                [self application:[UIApplication sharedApplication] handleOpenURL:urlFromUserInfo];
            } else {
                // Download pressed
                [self startBackgroundDownloadWithUserInfo:userInfo];
            }
            break;
        default:
            break;
    }
}

#pragma mark - Download delegate

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    [[NIAUInAppPurchaseHelper sharedInstance] unzipAndMoveFilesForConnection:connection toDestinationURL:destinationURL];
}

- (void)connectionDidResumeDownloading:(NSURLConnection *)connection totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long)expectedTotalBytes
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long)expectedTotalBytes
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

#pragma mark -

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
