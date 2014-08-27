//
//  NIAUCategoryViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 5/12/2013.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUCategoryViewController.h"

@interface NIAUCategoryViewController ()

@end

@implementation NIAUCategoryViewController

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
        self.articlesArray = [[NSMutableArray alloc] init];
        self.issuesArray = [[NSMutableArray alloc] init];
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
    
    // Set the viewController title
    // Remove the slash and only take the last word
    NSArray *categoryParts = @[];
    NSString *textString = self.category;
    categoryParts = [textString componentsSeparatedByString:@"/"];
    self.title = [[categoryParts[[categoryParts count]-2] capitalizedString] stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    
    // Get all of the issues, and when that's done get all of the articles
    
    if([[NIAUPublisher getInstance] isReady]) {
        [self loadArticles];
    } else {
        [self loadIssues];
    }
    
    [self.tableViewLoadingIndicator startAnimating];
    
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
                                       value:[NSString stringWithFormat:@"Category - %@",self.title]];
    
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
    int numberOfIssuesDownloaded = (int)[[NIAUPublisher getInstance] numberOfIssues];
    for (int i = 0; i < numberOfIssuesDownloaded; i++) {
        self.issue = [[NIAUPublisher getInstance] issueAtIndex:i];
        [self.issuesArray addObject:self.issue];
        [self.issue requestArticles];
        if (i == (numberOfIssuesDownloaded - 1)) {
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
    // Load all articles into self.articlesArray
    NSMutableArray *allArticles = [NSMutableArray array];
    for (int i = 0; i < self.issuesArray.count; i++) {
        for (int a = 0; a < [self.issuesArray[i] numberOfArticles]; a++) {
            [allArticles addObject:[self.issuesArray[i] articleAtIndex:a]];
        }
    }
    
    // Save only the articles of this category to self.articlesArray
    for (int a = 0; a < allArticles.count; a++) {
        for (int c = 0; c < [[allArticles[a] categories] count]; c++) {
            NSDictionary *category = [allArticles[a] categories][c];
            if ([[category objectForKey:@"name"] isEqualToString:self.category] || ([NSNumber numberWithInt:[[category objectForKey:@"id"] intValue]] == self.categoryID)) {
                [self.articlesArray addObject:allArticles[a]];
            }
        }
    }
    
    // Stop loading indicator & remove it's UIView
    [self.tableViewLoadingIndicator stopAnimating];
    [self.loadingIndicatorView removeFromSuperview];
    self.tableView.tableHeaderView = nil;
    
    [self showCategoryArticles];
}

- (void)showCategoryArticles
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
    if (self.articlesArray.count > 0) {
        return self.articlesArray.count;
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"articlesInCategoryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
    
    UIImageView *articleImage = (UIImageView *)[cell viewWithTag:100];
    UILabel *articleTitle = (UILabel *)[cell viewWithTag:101];
    UILabel *articleTeaser = (UILabel *)[cell viewWithTag:102];
    UILabel *articleDate = (UILabel *)[cell viewWithTag:103];
    NIAUArticle *article = self.articlesArray[indexPath.row];
    
    articleTitle.text = [article title];
    
    // Regex to remove <strong> and <b> and any other <html>
    id teaser = [article teaser];
    teaser = (teaser==[NSNull null]) ? @"" : teaser;
    
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:NSRegularExpressionCaseInsensitive error:&error];
    NSString *cleanTeaser = [regex stringByReplacingMatchesInString:teaser options:0 range:NSMakeRange(0, [teaser length]) withTemplate:@""];
    articleTeaser.text = cleanTeaser;
    
    // Set the article date
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    [dateFormatter setDateFormat:@"MMMM yyyy"];
    articleDate.text = [NSString stringWithFormat: @"%@ - %@", [[article issue] name], [dateFormatter stringFromDate:[[article issue] publication]]];
    
    // Set background colour to the category colour.
    NSDictionary *firstCategory = article.categories.firstObject;
    id categoryColour = WITH_DEFAULT([firstCategory objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
    articleImage.backgroundColor = UIColorFromRGB([categoryColour integerValue]);
    
    // Get featured image
    articleImage.image = nil;
    CGSize thumbSize = CGSizeMake(57,90);
    if (self.tableView.dragging == NO && self.tableView.decelerating == NO) {
        [article getFeaturedImageThumbWithSize:thumbSize andCompletionBlock:^(UIImage *thumb) {
            if (thumb) {
                [NIAUHelper fadeInImage:thumb intoImageView:articleImage];
            } else {
                // If the article has an article image, get it.
                NSDictionary *firstImage = [article firstImage];
                if ([firstImage count] > 0) {
                    [article getFirstImageWithID:[[firstImage objectForKey:@"id"] stringValue] andSize:thumbSize withCompletionBlock:^(UIImage *img) {
                        if (img) {
                            [NIAUHelper fadeInImage:img intoImageView:articleImage];
                        }
                    }];
                }
            }
        }];
    } else {
        UIImage *thumb = [article attemptToGetFeaturedImageThumbFromDiskWithSize:thumbSize];
        if (thumb) {
            [NIAUHelper fadeInImage:thumb intoImageView:articleImage];
        } else {
            // If the article has an article image, get it.
            NSDictionary *firstImage = [article firstImage];
            if ([firstImage count] > 0) {
                [article getFirstImageWithID:[[firstImage objectForKey:@"id"] stringValue] andSize:thumbSize withCompletionBlock:^(UIImage *img) {
                    if (img) {
                        [NIAUHelper fadeInImage:img intoImageView:articleImage];
                    }
                }];
            }
        }
    }
    
    // If articleImageView.image is still nil, no image is coming, so reduce the width of the coloured imageView.
    if (articleImage.image == nil) {
        [articleImage.constraints[0] setConstant:20.];
        [cell setSeparatorInset:UIEdgeInsetsMake(0, 21., 0, 0)];
        [articleImage setNeedsUpdateConstraints];
        [cell setNeedsLayout];
    }
    
    // Aminate the cell loading so that long category lists of articles fade in.
    [articleImage setAlpha:0.0];
    [articleTitle setAlpha:0.0];
    [articleTeaser setAlpha:0.0];
    [articleDate setAlpha:0.0];
    
    [UIView animateWithDuration:0.2 animations:^{
        [articleImage setAlpha:1.0];
        [articleTitle setAlpha:1.0];
        [articleTeaser setAlpha:1.0];
        [articleDate setAlpha:1.0];
    }];
    
    return cell;
}

- (CGSize)calculateCellSize:(UITableViewCell *)cell inTableView:(UITableView *)tableView {
    
    CGSize fittingSize = CGSizeMake(tableView.bounds.size.width, 0);
    CGSize size = [cell.contentView systemLayoutSizeFittingSize:fittingSize];
    
    return size;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
    
    return [self calculateCellSize:cell inTableView:tableView].height;
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
    
    NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
    articleViewController.article = self.articlesArray[selectedIndexPath.row];
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
