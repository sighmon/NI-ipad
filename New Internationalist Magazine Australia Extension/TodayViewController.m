//
//  TodayViewController.m
//  New Internationalist Magazine Australia Extension
//
//  Created by Simon Loffler on 15/09/2014.
//  Copyright (c) 2014 New Internationalist Australia. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>

static NSString *cellIdentifier = @"extensionCell";
static CGFloat padding = 22.0;

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
    
    // This will remove extra separators from tableview
//    self.articleTableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    // Add the iOS 10 Show More ability
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0")) {
        [self.extensionContext setWidgetLargestAvailableDisplayMode:NCWidgetDisplayModeExpanded];
    }
}

- (void)widgetActiveDisplayModeDidChange:(NCWidgetDisplayMode)activeDisplayMode withMaximumSize:(CGSize)maxSize {
    if (activeDisplayMode == NCWidgetDisplayModeCompact) {
        // Changed to compact mode
        self.preferredContentSize = maxSize;
    }
    else {
        // Changed to expanded mode
        self.preferredContentSize = CGSizeMake(self.articleTableView.contentSize.width, self.articleTableView.contentSize.height + padding);
    }
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
    
//    NSLog(@"\nTableView height: %f\nView height: %f", self.articleTableView.frame.size.height, self.view.frame.size.height);
    
    // Set height to tableview height
    self.preferredContentSize = self.articleTableView.contentSize;
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    // To avoid showing any headers.
    return nil;
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    // Load the recently read articles from user defaults
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

//- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    return 44.0 + 5.0;
//}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static UITableViewCell *sizingCell = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sizingCell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    });
    
    [self configureCell:sizingCell atIndexPath:indexPath];
    return [self calculateHeightForConfiguredSizingCell:sizingCell];
}

- (CGFloat)calculateHeightForConfiguredSizingCell:(UITableViewCell *)sizingCell
{
    // Auto-layout method didn't work. Boo hiss.
    [sizingCell setNeedsLayout];
    [sizingCell layoutIfNeeded];
    
    CGSize size = [sizingCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    
//    CGSize maxSize = CGSizeMake(sizingCell.textLabel.frame.size.width, MAXFLOAT);
//
//    CGRect labelRect = [sizingCell.textLabel.text boundingRectWithSize:maxSize options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:sizingCell.textLabel.font} context:nil];
    
//    NSLog(@"Label size %@", NSStringFromCGSize(labelRect.size));
    
    return ceil(size.height);
}

- (void)configureCell: (UITableViewCell *)cell atIndexPath: (NSIndexPath *)indexPath
{
    NSArray *recentlyReadArticles = [self getRecentlyReadArticlesFromUserDefaults];
    if (recentlyReadArticles && recentlyReadArticles.count > 0) {
        cell.textLabel.text = [[recentlyReadArticles objectAtIndex:indexPath.row] objectForKey:@"title"];
    } else {
        cell.textLabel.text = @"No recently read articles.";
    }
}

#pragma mark - UITableView did select

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *articleTapped = [[self getRecentlyReadArticlesFromUserDefaults] objectAtIndex:indexPath.row];
    
    if (articleTapped && articleTapped.count > 0) {
        // open the app to the article tapped
        [self.extensionContext openURL:[NSURL URLWithString:[NSString stringWithFormat:@"newint://issues/%@/articles/%@", [articleTapped objectForKey:@"issueRailsID"],[articleTapped objectForKey:@"railsID"]]] completionHandler:^(BOOL success) {
            // open the article
        }];
    } else {
        [self.extensionContext openURL:[NSURL URLWithString:[NSString stringWithFormat:@"newint://"]] completionHandler:^(BOOL success) {
            // Just opening the app to the default view.
        }];
    }
}

@end
