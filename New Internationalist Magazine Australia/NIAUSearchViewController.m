//
//  NIAUSearchViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 16/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUSearchViewController.h"

@interface NIAUSearchViewController ()

@end

@implementation NIAUSearchViewController

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
//        self.filteredIssuesArray = [[NSMutableArray alloc] init];
        self.filteredIssueArticlesArray = [[NSMutableArray alloc] init];
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
    
    // Setup two finger swipe to pop to root view
    UISwipeGestureRecognizer *twoFingerSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerSwipe:)];
    twoFingerSwipe.numberOfTouchesRequired = 2;
    
    [self.view addGestureRecognizer:twoFingerSwipe];
    
    // Add observer for the user changing the text size
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    [self sendGoogleAnalyticsStats];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)sendGoogleAnalyticsStats
{
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:@"Search"];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createAppView] build]];
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
    alert.delegate = nil;
}

- (void)articlesReady:(NSNotification *)notification
{
//    NSLog(@"Articles loaded OK.");
//    for (int i = 0; i < [self.issue numberOfArticles]; i++) {
//        [self.articlesArray addObject:[self.issue articleAtIndex:i]];
//    }
    [self showIssues];
}

- (void)showIssues
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
    // Return the number of sections. (number of issues)
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return [self.filteredIssueArticlesArray count];
    } else {
        return [self.issuesArray count];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    // TODO: WORK OUT HOW TO CHANGE THE BACKGROUND COLOUR FOR THE HEADERS.
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        NIAUIssue *issue = [(NIAUArticle *)[[self.filteredIssueArticlesArray objectAtIndex:section] firstObject] issue];
        return [NSString stringWithFormat:@"%@ - %@", [issue name], [issue title]];
    } else {
        return [NSString stringWithFormat:@"%@ - %@", [[self.issuesArray objectAtIndex:section] name], [[self.issuesArray objectAtIndex:section] title]];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return [self.filteredIssueArticlesArray[section] count];
    } else {
        return [self.issuesArray[section] numberOfArticles];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"searchViewCell";
    
    UITableViewCell *cell = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    } else {
        cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    }
    
    // Configure the cell...
    
    NIAUArticle *article = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        article = self.filteredIssueArticlesArray[indexPath.section][indexPath.row];
    } else {
        article = [self.issuesArray[indexPath.section] articleAtIndex:indexPath.row];
    }
    
    // Hack to check against NULL teasers.
    id teaser = article.teaser;
    teaser = (teaser==[NSNull null]) ? @"" : teaser;
    
    cell.textLabel.text = article.title;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    
    // Regex to remove <strong> and <b> and any other <html>
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:NSRegularExpressionCaseInsensitive error:&error];
    NSString *cleanTeaser = [regex stringByReplacingMatchesInString:teaser options:0 range:NSMakeRange(0, [teaser length]) withTemplate:@""];
    
    cell.detailTextLabel.text = cleanTeaser;
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Using technique from http://stackoverflow.com/questions/18897896/replacement-for-deprecated-sizewithfont-in-ios-7
        
    NIAUArticle *article = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        article = self.filteredIssueArticlesArray[indexPath.section][indexPath.row];
    } else {
        article = [self.issuesArray[indexPath.section] articleAtIndex:indexPath.row];
    }
    
    id teaser = article.teaser;
    teaser = (teaser==[NSNull null]) ? @"" : teaser;
    
    NSString *articleTitle = article.title;
    if (articleTitle == nil) {
        // Hmmm.. something fishy going on, but let's avoid a crash
        articleTitle = @"";
    }
    CGFloat width = tableView.frame.size.width - 50;
    
    UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:articleTitle attributes:@{ NSFontAttributeName : font }];
    CGRect rect = [attributedText boundingRectWithSize:(CGSize){width, CGFLOAT_MAX}
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                               context:nil];
    CGSize sizeofTitle = rect.size;
    
    UIFont *teaserFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    NSAttributedString *attributedTextTeaser = [[NSAttributedString alloc] initWithString:teaser attributes:@{ NSFontAttributeName : teaserFont }];
    CGRect teaserRect = [attributedTextTeaser boundingRectWithSize:(CGSize){width, CGFLOAT_MAX}
                                                           options:NSStringDrawingUsesLineFragmentOrigin
                                                           context:nil];
    CGSize sizeofTeaser = teaserRect.size;
    
    return ceilf(sizeofTitle.height + sizeofTeaser.height) + 30.;
}

#pragma mark -
#pragma mark Search filtering

-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    // Update the filtered array based on the search text and scope.
    // Remove all objects from the filtered search array

    [self.filteredIssueArticlesArray removeAllObjects];
    
    // Filter the array using NSPredicate
    
    [self.issuesArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        NSMutableArray *filteredArticlesArray = [[NSMutableArray alloc] initWithCapacity:[obj numberOfArticles]];
        for (int i = 0; i < [obj numberOfArticles]; i++) {
            [filteredArticlesArray addObject:[obj articleAtIndex:i]];
        }
        
        NSArray *searchArray = [searchText componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,\t"]];
        
        NSMutableArray *andPredicateArray = [NSMutableArray array];
        
        [searchArray enumerateObjectsUsingBlock:^(NSString *subString, NSUInteger idx, BOOL *stop) {
            if ([subString length] > 0) {
                NSMutableArray *searchArticleTitleAndTeaser = [NSMutableArray array];
                [searchArticleTitleAndTeaser addObject:[NSPredicate predicateWithFormat:@"SELF.title contains[cd] %@",subString]];
                [searchArticleTitleAndTeaser addObject:[NSPredicate predicateWithFormat:@"SELF.teaser contains[cd] %@",subString]];
                [searchArticleTitleAndTeaser addObject:[NSPredicate predicateWithFormat:@"SELF.attemptToGetBodyFromDisk contains[cd] %@",subString]];
                NSPredicate *orPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:searchArticleTitleAndTeaser];
                [andPredicateArray addObject:orPredicate];
            }
        }];
        
        NSPredicate *compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:andPredicateArray];

        [filteredArticlesArray filterUsingPredicate:compoundPredicate];
        
        if ([filteredArticlesArray count] > 0) {
            [self.filteredIssueArticlesArray addObject:filteredArticlesArray];
        }
    }];
}

#pragma mark - 
#pragma mark UISearchDisplayController Delegate Methods

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    // Tells the table data source to reload when text changes
    [self filterContentForSearchText:searchString scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    // Tells the table data source to reload when scope bar selection changes
    [self filterContentForSearchText:self.searchDisplayController.searchBar.text scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    // Return YES to cause the search result table view to be reloaded.
    return YES;
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

#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    NIAUArticleViewController *articleViewController = [segue destinationViewController];
    
    if([sender isDescendantOfView:self.searchDisplayController.searchResultsTableView]) {
        NSIndexPath *selectedIndexPath = [self.searchDisplayController.searchResultsTableView indexPathForSelectedRow];
        articleViewController.article = self.filteredIssueArticlesArray[selectedIndexPath.section][selectedIndexPath.row];
    }
    else {
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
        articleViewController.article = [[self.issuesArray objectAtIndex:selectedIndexPath.section] articleAtIndex:selectedIndexPath.row];
    }
}

#pragma mark - Gestures

- (void)handleTwoFingerSwipe:(UISwipeGestureRecognizer *)swipe
{
    // Pop back to the root view controller on triple tap
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark - Dynamic Text

- (void)preferredContentSizeChanged:(NSNotification *)notification
{
    NSLog(@"Notification received for text change!");
    
    [self.tableView reloadData];
}

@end
