//
//  NIAUCategoriesViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 4/12/2013.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUCategoriesViewController.h"

@interface NIAUCategoriesViewController ()

@end

@implementation NIAUCategoriesViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Initialize the arrays
        self.issuesArray = [[NSMutableArray alloc] init];
        self.articlesArray = [[NSMutableArray alloc] init];
        self.categoriesArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Get all of the issues, and when that's done get all of the articles
    if([[NIAUPublisher getInstance] isReady]) {
        [self loadArticles];
    } else {
        [self loadIssues];
    }
}

- (void)loadIssues
{
    NSLog(@"Loading issues...");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherFailed:) name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];
    [[NIAUPublisher getInstance] requestIssues];
}

- (void)loadArticles
{
    // Do this for all issues.
    for (int i = 0; i < [[NIAUPublisher getInstance] numberOfIssues]; i++) {
        self.issue = [[NIAUPublisher getInstance] issueAtIndex:i];
        [self.issuesArray addObject:self.issue];
        [self.issue requestArticles];
        if (i == ([[NIAUPublisher getInstance] numberOfIssues] - 1)) {
            NSLog(@"Last issue reached.. setting observer.");
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(articlesReady:) name:ArticlesDidUpdateNotification object:self.issue];
        }
    }
}

- (void)publisherReady:(NSNotification *)notification
{
    // issues are downloaded, now get the articles.
    NSLog(@"Issues loaded OK.");
    [self loadArticles];
    NSLog(@"Loading articles...");
}

- (void)publisherFailed:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];
    NSLog(@"%@",notification);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:@"Cannot get issues from publisher server."
                                                   delegate:nil
                                          cancelButtonTitle:@"Close"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)articlesReady:(NSNotification *)notification
{
    for (int i = 0; i < [self.issuesArray count]; i++) {
        for (int a = 0; a < [self.issuesArray[i] numberOfArticles]; a++) {
            // Add articles to the articles array
            [self.articlesArray addObject:[self.issuesArray[i] articleAtIndex:a]];
            for (int c = 0; c < [[self.issuesArray[i] articleAtIndex:a].categories count]; c++) {
                // Add categories to the categories array only if they're unique
                NSDictionary *objectToAdd = [self.issuesArray[i] articleAtIndex:a].categories[c];
                if (![self.categoriesArray containsObject:objectToAdd]) {
                    [self.categoriesArray addObject:objectToAdd];
                }
            }
        }
    }
    // Sort the categoriesArray
    [self.categoriesArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDictionary *d1 = obj1, *d2 = obj2;
        return [[d1 objectForKey:@"name"] caseInsensitiveCompare:[d2 objectForKey:@"name"]];
    }];
    
    [self showCategories];
}

- (void)showCategories
{
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    if (self.categoriesArray && [self.categoriesArray count] > 0) {
        return [self.categoriesArray count];
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"categoriesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    
    cell.textLabel.text = [self.categoriesArray[indexPath.row] objectForKey:@"name"];
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

@end
