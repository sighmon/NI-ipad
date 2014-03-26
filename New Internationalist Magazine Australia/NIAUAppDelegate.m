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
#import "NIAUIssue.h"
#import <objc/runtime.h>
const char NotificationKey;

#import "GAI.h"
#import "GAITracker.h"
#import "GAITrackedViewController.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "GAILogger.h"

@implementation NIAUAppDelegate
{
    BOOL moveSuccess;
}

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
    
    // Google Analytics
    
    // Optional: automatically send uncaught exceptions to Google Analytics.
    [GAI sharedInstance].trackUncaughtExceptions = YES;
    
    // Optional: set Google Analytics dispatch interval to e.g. 20 seconds.
    [GAI sharedInstance].dispatchInterval = 20;
    
    // Optional: set Logger to VERBOSE for debug information.
//    [[[GAI sharedInstance] logger] setLogLevel:kGAILogLevelVerbose];
    
    // Initialize tracker.
    id<GAITracker> tracker = [[GAI sharedInstance] trackerWithTrackingId:GOOGLE_ANALYTICS_ID];
    NSLog(@"Google Analytics tracker initialized: %@", tracker);
    
    // If user hasn't set a default, set it to TRUE
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"googleAnalytics"] == nil) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:TRUE forKey:@"googleAnalytics"];
        [userDefaults synchronize];
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"googleAnalytics"] == 0) {
        // User has asked to opt-out of Google Analytics
        [[GAI sharedInstance] setOptOut:YES];
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
        NSNumber *articleID = [NSNumber numberWithInt:(int)[articleIDFromURL integerValue]];
        NSString *issueIDFromURL = [[url pathComponents] objectAtIndex:1];
        NSNumber *issueID = [NSNumber numberWithInt:(int)[issueIDFromURL integerValue]];
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
    if ((application.applicationState == UIApplicationStateInactive) || (application.applicationState == UIApplicationStateBackground)) {
        [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
        [self turnBadgeIconOn];
        [self handleRemoteNotification:application andUserInfo:userInfo];
    } else {
        [self handleNotification:userInfo];
        [PFPush handlePush:userInfo];
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if ((application.applicationState == UIApplicationStateInactive) || (application.applicationState == UIApplicationStateBackground)) {
        [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
        [self turnBadgeIconOn];
        [self handleRemoteNotification:application andUserInfo:userInfo];
    } else {
        [self handleNotification:userInfo];
    }
}

- (void)handleRemoteNotification: (UIApplication *)application andUserInfo: (NSDictionary *)userInfo
{
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

- (void)handleNotification: (NSDictionary *)userInfo
{
    NSLog(@"UserInfo: %@", userInfo);
    // Ask the user whether they want to download the new issue now
    NSString *message = [NSString stringWithFormat:@"%@ Would you like to download it now in the background?", [[userInfo objectForKey:@"aps"] objectForKey:@"alert"]];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New issue available" message:message delegate:self cancelButtonTitle:@"Not now." otherButtonTitles:@"Download", nil];
    [alert show];
    objc_setAssociatedObject(alert, &NotificationKey, userInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)turnBadgeIconOn
{
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 1];
}

- (void)startBackgroundDownloadWithUserInfo: (NSDictionary *)userInfo
{
    // TODO: get zip file from Rails, unpack it and save it to the library as a new nkIssue.
    
    if(userInfo) {
        // TODO: Get the zipURL from Rails.
        NSString *railsID = [userInfo objectForKey:@"railsID"];
        NSString *zipURL = [self requestZipURLforRailsID: railsID];
        
        if (zipURL) {
            // Create NIAUIssue from userInfo
            NIAUIssue *newIssue = [NIAUIssue issueWithUserInfo:userInfo];
            
            // schedule for issue downloading in background
            NKIssue *newNKIssue = [[NKLibrary sharedLibrary] issueWithName:newIssue.name];
            if(newNKIssue) {
                NSURL *downloadURL = [NSURL URLWithString:zipURL];
                NSURLRequest *req = [NSURLRequest requestWithURL:downloadURL];
                NKAssetDownload *assetDownload = [newNKIssue addAssetWithRequest:req];
                [assetDownload downloadWithDelegate:self];
            }
        } else {
            NSLog(@"No zipURL, so aborting.");
        }
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
            // Download pressed
            [self startBackgroundDownloadWithUserInfo:userInfo];
            break;
        default:
            break;
    }
}

#pragma mark - Download delegate

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
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
                // Move this file
                filePath = [filePath stringByAppendingString:subDirFile];
                destinationPath = [destinationPath stringByAppendingString:subDirFile];
                [self moveFile:filePath toDestination:destinationPath];
            }
        } else {
            // Move this file
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

- (NSString *)requestZipURLforRailsID: (NSString *)railsID
{
    // get zipURL from Rails
    NSURL *issueURL = [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@.json", railsID] relativeToURL:[NSURL URLWithString:SITE_URL]];
    
    NSData *secretData = [RAILS_ISSUE_SECRET dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *base64receipt = [secretData base64EncodedStringWithOptions:0];
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
            // User isn't logged in, or login was wrong
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
