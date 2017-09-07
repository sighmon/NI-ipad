//
//  NIAUSearchViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 16/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUSearchViewController.h"
#import "local.h"

@interface NIAUSearchViewController ()

@end

@implementation NIAUSearchViewController

NSTimer *searchTimer;

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
        self.webSearchArticlesArray = [[NSMutableArray alloc] init];
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
    
    // Setup UISearchController
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.scopeButtonTitles = @[NSLocalizedString(@"scope_button_phone", nil),
                                                          NSLocalizedString(@"scope_button_web", nil)];
    self.searchController.searchBar.delegate = self;
    self.tableView.tableHeaderView = self.searchController.searchBar;
    self.definesPresentationContext = YES;
    [self.searchController.searchBar sizeToFit];
    
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
     send:[[GAIDictionaryBuilder createScreenView] build]];
}

- (void)loadIssues
{
    DebugLog(@"Loading issues...");
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
            DebugLog(@"Last issue reached.. setting observer.");
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(articlesReady:) name:ArticlesDidUpdateNotification object:self.issue];
        }
    }
}

- (void)publisherReady:(NSNotification *)notification
{
    // issues are downloaded, now get the articles.
    DebugLog(@"Issues loaded OK.");
    [self loadArticles];
    DebugLog(@"Loading articles...");
}

- (void)publisherFailed:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];
    NSLog(@"Error - Publisher failed: %@",notification);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:NSLocalizedString(@"publisher_error", nil)
                                                   delegate:nil
                                          cancelButtonTitle:@"Close"
                                          otherButtonTitles:nil];
    [alert show];
    alert.delegate = nil;
}

- (void)articlesReady:(NSNotification *)notification
{
    DebugLog(@"Articles loaded OK.");
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
    
    if (self.searchController.active && [self.searchController.searchBar selectedScopeButtonIndex] == 1) {
        // Web search results
        return 1;
    } else if (self.searchController.active) {
        // Local device search
        return [self.filteredIssueArticlesArray count];
    } else {
        return [self.issuesArray count];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    // TODO: WORK OUT HOW TO CHANGE THE BACKGROUND COLOUR FOR THE HEADERS.
    
    if (self.searchController.active && [self.searchController.searchBar selectedScopeButtonIndex] == 1) {
        return [NSString stringWithFormat:@"%lu Search results", (unsigned long)[self.webSearchArticlesArray count]];
    } else if (self.searchController.active) {
        NIAUIssue *issue = [(NIAUArticle *)[[self.filteredIssueArticlesArray objectAtIndex:section] firstObject] issue];
        return [NSString stringWithFormat:@"%@ - %@", [issue name], [issue title]];
    } else {
        return [NSString stringWithFormat:@"%@ - %@", [[self.issuesArray objectAtIndex:section] name], [[self.issuesArray objectAtIndex:section] title]];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    
    if (self.searchController.active && [self.searchController.searchBar selectedScopeButtonIndex] == 1) {
        return [self.webSearchArticlesArray count];
    } else if (self.searchController.active) {
        return [self.filteredIssueArticlesArray[section] count];
    } else {
        return [self.issuesArray[section] numberOfArticles];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"searchViewCell";
    
    UITableViewCell *cell = nil;
    
    if (self.searchController.active) {
        cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    } else {
        cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    }
    
    // Configure the cell...
    
    NIAUArticle *article = nil;
    id teaser = nil;
    
    if (self.searchController.active && [self.searchController.searchBar selectedScopeButtonIndex] == 1) {
        // Load the title & teaser later
        teaser = self.webSearchArticlesArray[indexPath.row][@"teaser"];
        cell.textLabel.text = self.webSearchArticlesArray[indexPath.row][@"title"];
    } else if (self.searchController.active) {
        article = self.filteredIssueArticlesArray[indexPath.section][indexPath.row];
        teaser = article.teaser;
        cell.textLabel.text = article.title;
    } else {
        article = [self.issuesArray[indexPath.section] articleAtIndex:indexPath.row];
        teaser = article.teaser;
        cell.textLabel.text = article.title;
    }
    
    // Hack to check against NULL teasers.
    if (teaser == nil || teaser == [NSNull null]) {
        teaser = @"";
    }
    
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
    id teaser = nil;
    NSString *articleTitle;
    
    if (self.searchController.active && [self.searchController.searchBar selectedScopeButtonIndex] == 1) {
        // Load the title & teaser later
        teaser = self.webSearchArticlesArray[indexPath.row][@"teaser"];
        articleTitle = self.webSearchArticlesArray[indexPath.row][@"title"];
    } else if (self.searchController.active) {
        article = self.filteredIssueArticlesArray[indexPath.section][indexPath.row];
        articleTitle = article.title;
        teaser = article.teaser;
    } else {
        article = [self.issuesArray[indexPath.section] articleAtIndex:indexPath.row];
        articleTitle = article.title;
        teaser = article.teaser;
    }
    
    if (teaser == nil || teaser == [NSNull null]) {
        teaser = @"";
    }
    
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
    
    NSMutableArray *tmpArray = [[NSMutableArray alloc] init];
    
    if (scope && [scope isEqualToString:NSLocalizedString(@"scope_button_phone", nil)]) {
        // Local device search
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
                [tmpArray addObject:filteredArticlesArray];
            }
        }];
        [self.filteredIssueArticlesArray removeAllObjects];
        [self.filteredIssueArticlesArray addObjectsFromArray:tmpArray];
        [self.tableView reloadData];
    } else {
        // Search the web
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        NSURL *searchURL = [NSURL URLWithString:[NSString stringWithFormat:@"search.json?query=%@&per_page=100", [searchText stringByReplacingOccurrencesOfString:@" " withString:@"+"]] relativeToURL:[NSURL URLWithString:SITE_URL]];
        [request setURL:searchURL];
        [request setHTTPMethod:@"GET"];
        [request setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"content-type"];
        
        NSError *error;
        NSHTTPURLResponse *response;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSArray *jsonArray;
        if (responseData) {
            jsonArray = [NSJSONSerialization JSONObjectWithData:responseData options: NSJSONReadingMutableContainers error: &error];
        }
//        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        int statusCode = (int)[response statusCode];
        if (statusCode >= 200 && statusCode < 300) {
            // Process json search results
            DebugLog(@"Search results: %lu", (unsigned long)[jsonArray count]);
            [self.webSearchArticlesArray removeAllObjects];
            [self.webSearchArticlesArray addObjectsFromArray:jsonArray];
            [self.tableView reloadData];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Search error" message:@"Sorry, either you don't have stable internet, or our site is down." delegate:self cancelButtonTitle:@"Try again." otherButtonTitles:nil] show];
        }
    }

}

#pragma mark -
#pragma mark UISearchController Delegate Methods

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    // Tells the table data source to reload when text changes
    NSString *searchString = searchController.searchBar.text;
    
    if (searchTimer.isValid) {
        [searchTimer invalidate];
    }
    searchTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(delayedSearch:) userInfo:@{@"searchString": searchString} repeats:NO];
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    if (searchTimer.isValid) {
        [searchTimer invalidate];
    }
    [self filterContentForSearchText:searchBar.text scope:[[self.searchController.searchBar scopeButtonTitles] objectAtIndex:[self.searchController.searchBar selectedScopeButtonIndex]]];
}

-(void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
{
    [self updateSearchResultsForSearchController:self.searchController];
}

-(void)delayedSearch:(NSTimer *)timer
{
    if (timer) {
        [self filterContentForSearchText:[timer userInfo][@"searchString"] scope:[[self.searchController.searchBar scopeButtonTitles] objectAtIndex:[self.searchController.searchBar selectedScopeButtonIndex]]];
    }
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
    
    if (self.searchController.active && [self.searchController.searchBar selectedScopeButtonIndex] == 1) {
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForCell:sender];
        NSString *articleIDFromURL = self.webSearchArticlesArray[selectedIndexPath.row][@"id"];
        NSNumber *articleID = [NSNumber numberWithInt:(int)[articleIDFromURL integerValue]];
        NSString *issueIDFromURL = self.webSearchArticlesArray[selectedIndexPath.row][@"issue_id"];
        NSNumber *issueID = [NSNumber numberWithInt:(int)[issueIDFromURL integerValue]];
        NSArray *arrayOfIssues = [NIAUIssue issuesFromNKLibrary];
        NSUInteger issueIndexPath = [arrayOfIssues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return ([[obj railsID] isEqualToNumber:issueID]);
        }];
        if (issueIndexPath != NSNotFound) {
            NIAUIssue *issue = [arrayOfIssues objectAtIndex:issueIndexPath];
            [issue forceDownloadArticles];
            NIAUArticle *articleToLoad = [issue articleWithRailsID:articleID];
            if (articleToLoad) {
                articleViewController.article = articleToLoad;
            } else {
                // Can't find that article..
            }
        } else {
            // Can't find that issue..
        }
    }
    else if (self.searchController.active && [segue.identifier isEqualToString:@"searchToArticleDetail"]) {
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForCell:sender];
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
