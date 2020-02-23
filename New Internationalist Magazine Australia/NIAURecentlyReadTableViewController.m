//
//  NIAURecentlyReadTableViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 14/2/20.
//  Copyright © 2020 New Internationalist Australia. All rights reserved.
//

#import "NIAURecentlyReadTableViewController.h"
#import "NIAUArticleViewController.h"

@interface NIAURecentlyReadTableViewController ()

@end

@implementation NIAURecentlyReadTableViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Initialize the arrays
        self.recentlyReadArticles = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Get the recentlyReadArticles
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.au.com.newint.New-Internationalist-Magazine-Australia"];
    self.recentlyReadArticles = [userDefaults objectForKey:@"recentlyReadArticles"];
}

- (void)viewDidAppear:(BOOL)animated
{
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.au.com.newint.New-Internationalist-Magazine-Australia"];
    self.recentlyReadArticles = [userDefaults objectForKey:@"recentlyReadArticles"];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.recentlyReadArticles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellIdentifier = @"recentlyReadViewCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    // Configure the cell
    NSDictionary *article = [self.recentlyReadArticles objectAtIndex:indexPath.row];
    cell.textLabel.text = [article objectForKey:@"title"];
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];

    NSDate *dateRead = [article objectForKey:@"dateRead"];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEEE h:mma, d MMMM, yyyy"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Read: %@", [dateFormatter stringFromDate:dateRead]];
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"Recently read articles";
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    NIAUArticleViewController *articleViewController = [segue destinationViewController];
    NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
    NSDictionary *articleRead = [self.recentlyReadArticles objectAtIndex:selectedIndexPath.row];
    NIAUIssue *issue = [[NIAUPublisher getInstance] issueWithRailsID:[articleRead objectForKey:@"issueRailsID"]];
    [issue forceDownloadArticles];
    NIAUArticle *article = [issue articleWithRailsID:[articleRead objectForKey:@"railsID"]];
    articleViewController.article = article;
}

@end
