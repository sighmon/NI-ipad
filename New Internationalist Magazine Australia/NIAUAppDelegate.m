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
#import <Parse/Parse.h>
#import "local.h"
#import "NIAUPublisher.h"
#import "NIAUArticleViewController.h"
#import "NIAUArticle.h"

@implementation NIAUAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Load the In App Purchase Helper at launch to check for unfinished purchases.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [NIAUInAppPurchaseHelper sharedInstance];
    });
    
    // Setup Parse for Notifications
    [Parse setApplicationId:PARSE_APPLICATION_ID
                  clientKey:PARSE_CLIENT_KEY];
        
    // Parse tracking analytics
//    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
    if (application.applicationState != UIApplicationStateBackground) {
        // Track an app open here if we launch with a push, unless
        // "content_available" was used to trigger a background push (introduced
        // in iOS 7). In that case, we skip tracking here to avoid double counting
        // the app-open.
        BOOL preBackgroundPush = ![application respondsToSelector:@selector(backgroundRefreshStatus)];
        BOOL oldPushHandlerOnly = ![self respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)];
        BOOL noPushPayload = ![launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (preBackgroundPush || oldPushHandlerOnly || noPushPayload) {
            [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
        }
    }
    
    // Setup app to receive UIRemoteNotifications
    [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge|
     UIRemoteNotificationTypeAlert|
     UIRemoteNotificationTypeSound|
     UIRemoteNotificationTypeNewsstandContentAvailability];
    
    // TODO: Remove this for launch - allows multiple NewsStand notifications. :-)
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NKDontThrottleNewsstandContentNotifications"];
    
    // When we receive a Remote Notification, grab the issue number from the payload and download it.
    NSDictionary *payload = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if(payload) {        
        // This only fires if the application is launched from a remote notification by the user
        // Also fires when the newsstand content-available starts the app in the background.
        
        [self handleRemoteNotification:application andUserInfo:payload];
    }
    
    // Override point for customization after application launch.
    return YES;
}

#pragma mark - URL open handling

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    // Launched from a link newint://issues/id/articles/id
    
    BOOL okayToLoad = false;
    
    NSError *error = NULL;
    NSRegularExpression *URLRegex = [NSRegularExpression regularExpressionWithPattern:@"(issues)\\/(\\d+)\\/(articles)\\/(\\d+)"
                                                                              options:NSRegularExpressionCaseInsensitive
                                                                                error:&error];
    
    NSUInteger numberOfMatches = [URLRegex numberOfMatchesInString:[url absoluteString]
                                                           options:0
                                                             range:NSMakeRange(0, [[url absoluteString] length])];
    
    if ((numberOfMatches > 0) && !error && [[url absoluteString] hasPrefix:@"newint"]) {
        // The launch string passes regex, so should be okay
        // TODO: handle ids not found.
        okayToLoad = true;
    }
    
    if (okayToLoad) {
        // It's probably a good link, so let's load it.
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:[NSBundle mainBundle]];
        
        NIAUArticleViewController *articleViewController = [storyboard instantiateViewControllerWithIdentifier:@"article"];
        
        NSString *articleIDFromURL = [[url pathComponents] lastObject];
        NSNumber *articleID = [NSNumber numberWithInt:[articleIDFromURL integerValue]];
        NSString *issueIDFromURL = [[url pathComponents] objectAtIndex:1];
        NSNumber *issueID = [NSNumber numberWithInt:[issueIDFromURL integerValue]];
        NSArray *arrayOfIssues = [NIAUIssue issuesFromNKLibrary];
        NIAUIssue *issue = [arrayOfIssues objectAtIndex:[arrayOfIssues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return ([[obj railsID] isEqualToNumber:issueID]);
        }]];
        [issue forceDownloadArticles];
        
        articleViewController.article = [issue articleWithRailsID:articleID];
        [(UINavigationController*)self.window.rootViewController pushViewController:articleViewController animated:YES];
        
        return YES;
    } else {
        // Malformed link, so ignore it and just start the app.
        [[[UIAlertView alloc] initWithTitle:@"Sorry!" message:@"We don't recognise that link that you tried to open." delegate:self cancelButtonTitle:@"Okay." otherButtonTitles: nil] show];
        return NO;
    }
}

#pragma mark - Parse setup

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    // Store the deviceToken in the current installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    [currentInstallation saveInBackground];
    NSLog(@"Parse installation objectId: %@", [currentInstallation objectId]);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    // This notification fires when the user has the app open and a notification comes in.
    [self handleNotification:userInfo];
    [PFPush handlePush:userInfo];
    if (application.applicationState == UIApplicationStateInactive) {
        [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
        [self turnBadgeIconOn];
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    // This notification fires when the user has the app open and a notification comes in.
    [self handleNotification:userInfo];
    if (application.applicationState == UIApplicationStateInactive) {
        [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
        [self turnBadgeIconOn];
    }
}

- (void)handleRemoteNotification: (UIApplication *)application andUserInfo: (NSDictionary *)userInfo
{
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
    
    // Start background download.
    [self startBackgroundDownload];
}

- (void)handleNotification: (NSDictionary *)userInfo
{
    NSLog(@"UserInfo: %@", userInfo);
    // Ask the user whether they want to download the new issue now
    NSString *message = [NSString stringWithFormat:@"%@ Would you like to download it now in the background?", [[userInfo objectForKey:@"aps"] objectForKey:@"alert"]];
    [[[UIAlertView alloc] initWithTitle:@"New issue available" message:message delegate:self cancelButtonTitle:@"Not now." otherButtonTitles:@"Download", nil] show];
}

- (void)turnBadgeIconOn
{
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 1];
}

- (void)startBackgroundDownload
{
    // TODO: get zip file from Rails, unpack it and save it to the library.
    
    // For now lets just force update the issues
    [[NIAUPublisher getInstance] forceDownloadIssues];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshViewNotification" object:nil];
    
    // So we know this has run...
    NSString *message = [NSString stringWithFormat:@"Totally doing it."];
    [[[UIAlertView alloc] initWithTitle:@"Sure thing." message:message delegate:self cancelButtonTitle:@"Cool." otherButtonTitles:nil] show];
}

#pragma mark AlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0:
            // Cancel pressed
            break;
        case 1:
            // Download pressed
            [self startBackgroundDownload];
            break;
        default:
            break;
    }
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
