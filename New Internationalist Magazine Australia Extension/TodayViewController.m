//
//  TodayViewController.m
//  New Internationalist Magazine Australia Extension
//
//  Created by Simon Loffler on 15/09/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>

@interface TodayViewController () <NCWidgetProviding>

@end

@implementation TodayViewController

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userDefaultsDidChange:)
                                                     name:NSUserDefaultsDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self updateReadingList];
    
    // Call this to fit to size of articleTableView.
    [self setPreferredContentSize:self.articleTableView.frame.size];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData
    
    [self updateReadingList];
    
    completionHandler(NCUpdateResultNewData);
}

- (void)userDefaultsDidChange:(NSNotification *)notification {
    [self updateReadingList];
}

- (void)updateReadingList
{
    [self.articleTableView reloadData];
}

- (NSArray *)getRecentlyReadArticlesFromUserDefaults
{
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.au.com.newint.New-Internationalist-Magazine-Australia"];
    return [userDefaults objectForKey:@"recentlyReadArticles"];
}

- (void)syncRecentlyReadArticlesToUserDefaults: (NSArray *)recentlyReadArticles
{
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.au.com.newint.New-Internationalist-Magazine-Australia"];
    [userDefaults setObject:recentlyReadArticles forKey:@"recentlyReadArticles"];
    [userDefaults synchronize];
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
    NSArray *recentlyReadArticles = [self getRecentlyReadArticlesFromUserDefaults];
    if (recentlyReadArticles && recentlyReadArticles.count > 0) {
        return recentlyReadArticles.count;
    } else {
        return 1;
    }
}

// Editing doesn't make sense here. Swiping right takes you to notifications.

//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//    tableView.sectionIndexBackgroundColor = [UIColor clearColor];
//    return @"Recently read articles";
//}

//- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    return YES;
//}
//
//// Override to support editing the table view.
//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    if (editingStyle == UITableViewCellEditingStyleDelete) {
//        //add code here for when you hit delete
//        NSMutableArray *recentlyReadArticles = [[NSMutableArray alloc] initWithArray:[self getRecentlyReadArticlesFromUserDefaults]];
//        [recentlyReadArticles removeObjectAtIndex:indexPath.row];
//        [self syncRecentlyReadArticlesToUserDefaults:recentlyReadArticles];
//        [tableView reloadData];
//    }
//}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"extensionCell" forIndexPath:indexPath];
    
    // Load the recently read articles from user defaults
    NSArray *recentlyReadArticles = [self getRecentlyReadArticlesFromUserDefaults];
    if (recentlyReadArticles && recentlyReadArticles.count > 0) {
        cell.textLabel.text = [[recentlyReadArticles objectAtIndex:indexPath.row] objectForKey:@"title"];
    } else {
        cell.textLabel.text = @"No recently read articles.";
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *articleTapped = [[self getRecentlyReadArticlesFromUserDefaults] objectAtIndex:indexPath.row];
    
    if (articleTapped && articleTapped.count > 0) {
        // open the app to the article tapped
        [self.extensionContext openURL:[NSURL URLWithString:[NSString stringWithFormat:@"newint://issues/%@/articles/%@", [articleTapped objectForKey:@"issueRailsID"],[articleTapped objectForKey:@"railsID"]]] completionHandler:^(BOOL success) {
            // open the article
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }];
    } else {
        [self.extensionContext openURL:[NSURL URLWithString:[NSString stringWithFormat:@"newint://"]] completionHandler:^(BOOL success) {
            // Just opening the app to the default view.
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }];
    }
}

@end
