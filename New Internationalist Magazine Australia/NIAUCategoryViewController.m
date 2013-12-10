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
    int numberOfIssuesDownloaded = [[NIAUPublisher getInstance] numberOfIssues];
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
            if ([[[allArticles[a] categories][c] objectForKey:@"name"] isEqualToString:self.category]) {
                [self.articlesArray addObject:allArticles[a]];
            }
        }
    }
    
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
    
//    // Load CSS from the filesystem
//    NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"article-body" withExtension:@"css"];
//    
//    // Load the article teaser into the attributedText
//    NSString *teaserHTML = [NSString stringWithFormat:@"<html> \n"
//                            "<head> \n"
//                            "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\">"
//                            "</head> \n"
//                            "<body><div class='table-of-contents-article-teaser'>%@</div></body> \n"
//                            "</html>", cssURL, [article teaser]];
//    
//    articleTeaser.attributedText = [[NSAttributedString alloc] initWithData:[teaserHTML dataUsingEncoding:NSUTF8StringEncoding]
//                                                                    options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
//                                                                              NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
//                                                         documentAttributes:nil
//                                                                      error:nil];
    
    // Regex to remove <strong> and <b> and any other <html>
    NSString *teaser = [article teaser];
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:NSRegularExpressionCaseInsensitive error:&error];
    NSString *cleanTeaser = [regex stringByReplacingMatchesInString:teaser options:0 range:NSMakeRange(0, [teaser length]) withTemplate:@""];
    articleTeaser.text = cleanTeaser;
    
    // Set the article date
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMMM yyyy"];
    articleDate.text = [NSString stringWithFormat: @"%@ - %@", [[article issue] name], [dateFormatter stringFromDate:[[article issue] publication]]];
    
    // Set background colour to the category colour.
    NSDictionary *firstCategory = article.categories.firstObject;
    id categoryColour = WITH_DEFAULT([firstCategory objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
    articleImage.backgroundColor = UIColorFromRGB([categoryColour integerValue]);
    
    // Get featured image
    articleImage.image = nil;
//    CGSize sizeOfCell = [self calculateCellSize:cell inTableView:tableView]; // Was too time consuming!
    CGSize thumbSize = CGSizeMake(57,90);
    if (self.tableView.dragging == NO && self.tableView.decelerating == NO) {
        [article getFeaturedImageThumbWithSize:thumbSize andCompletionBlock:^(UIImage *thumb) {
            [articleImage setImage:thumb];
            [cell setNeedsLayout];
        }];
    } else {
        UIImage *thumb = [article attemptToGetFeaturedImageThumbFromDiskWithSize:thumbSize];
        if(thumb) {
            [articleImage setImage:thumb];
            [cell setNeedsLayout];
        }
    }
    
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

@end
