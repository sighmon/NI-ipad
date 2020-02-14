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
        self.sectionsArray = [[NSMutableArray alloc] init];
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
    NSString *screenName = @"Categories";
    
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:screenName];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createScreenView] build]];
    
    // Firebase send
    [FIRAnalytics logEventWithName:@"openScreen"
                        parameters:@{
                                     @"name": screenName,
                                     @"screenName": screenName
                                     }];
    DebugLog(@"Firebase pushed: %@", screenName);
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
    // Clear array
    self.issuesArray = [NSMutableArray array];
    
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
    // Clear the arrays
    self.articlesArray = [NSMutableArray array];
    self.categoriesArray = [NSMutableArray array];
    self.sectionsArray = [NSMutableArray array];
    
    for (int i = 0; i < [self.issuesArray count]; i++) {
        for (int a = 0; a < [self.issuesArray[i] numberOfArticles]; a++) {
            // Add articles to the articles array
            [self.articlesArray addObject:[self.issuesArray[i] articleAtIndex:a]];
            for (int c = 0; c < [[self.issuesArray[i] articleAtIndex:a].categories count]; c++) {
                // Add categories to the categories array only if they're unique
                NSDictionary *objectToAdd = [self.issuesArray[i] articleAtIndex:a].categories[c];
                NSUInteger categoryIndex = [self.categoriesArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                    return [[obj objectForKey:@"name"] isEqualToString:[objectToAdd objectForKey:@"name"]];
                }];
                if (categoryIndex == NSNotFound) {
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
    
    // Remove the slashs' and get unique first category name
    
    for (int i = 0; i < self.categoriesArray.count; i++) {
        NSMutableDictionary *category = [NSMutableDictionary dictionaryWithDictionary:self.categoriesArray[i]];
        NSArray *categoryParts = @[];
        NSString *textString = [self.categoriesArray[i] objectForKey:@"name"];
        categoryParts = [textString componentsSeparatedByString:@"/"];
        
        NSString *sectionName = @"";
        // Handle no slashes from Drupal
        if ([categoryParts count] > 1) {
            sectionName = categoryParts[1];
        } else {
            // No slashes, new Drupal category type.
            sectionName = @"miscellaneous";
        }
        
        if ([categoryParts containsObject:@"regions"]) {
            sectionName = [NSString stringWithFormat:@"countries"];
        }
        [category setObject:sectionName forKey:@"sectionName"];
        
        if ([categoryParts count] > 1) {
            [category setObject:[[categoryParts[[categoryParts count]-2] capitalizedString] stringByReplacingOccurrencesOfString:@"-" withString:@" "] forKey:@"displayName"];
        } else {
            // No slashes, new Drupal category type.
            [category setObject:[[categoryParts[0] capitalizedString] stringByReplacingOccurrencesOfString:@"-" withString:@" "] forKey:@"displayName"];
        }
        
        
        if (self.sectionsArray.count > 0) {
            NSUInteger sectionIndex = [self.sectionsArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [[[obj firstObject] objectForKey:@"sectionName"] isEqualToString:sectionName];
            }];
            
            if (sectionIndex == NSNotFound) {
                // Make a new section
                [self.sectionsArray addObject:[NSMutableArray arrayWithObject:category]];
            } else {
                // Add ourselves to the section
                [self.sectionsArray[sectionIndex] addObject:category];
            }
        } else {
            // Make a new section
            [self.sectionsArray addObject:[NSMutableArray arrayWithObject:category]];
        }
    }
    
    // Sort the sectionsArray
    [self.sectionsArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDictionary *d1 = [obj1 firstObject], *d2 = [obj2 firstObject];
        return [[d1 objectForKey:@"sectionName"] caseInsensitiveCompare:[d2 objectForKey:@"sectionName"]];
    }];
    
    // Sort the categories within a section
    for (int i = 0; i < [self.sectionsArray count]; i++) {
        [self.sectionsArray[i] sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [[obj1 objectForKey:@"displayName"] caseInsensitiveCompare:[obj2 objectForKey:@"displayName"]];
        }];
    }
    
    // Stop loading indicator & remove its UIView
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableViewLoadingIndicator stopAnimating];
        [self.loadingIndicatorView removeFromSuperview];
        self.tableView.tableHeaderView = nil;
        [self showCategories];
    });
}

- (void)showCategories
{
    [self.tableView reloadData];
    NSRange range = NSMakeRange(0, self.sectionsArray.count);
    NSIndexSet *section = [NSIndexSet indexSetWithIndexesInRange:range];
    [self.tableView reloadSections:section withRowAnimation:UITableViewRowAnimationFade];
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
    return self.sectionsArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (self.sectionsArray && [self.sectionsArray count] > 0) {
        return [self.sectionsArray[section] count];
    } else {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [[self.sectionsArray[section] firstObject] objectForKey:@"sectionName"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"categoriesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    
    // Remove the slash and only take the last word
    NSArray *categoryParts = @[];
    NSString *textString = [self.sectionsArray[indexPath.section][indexPath.row] objectForKey:@"name"];
    categoryParts = [textString componentsSeparatedByString:@"/"];
    if ([categoryParts count] > 1) {
        cell.textLabel.text = [[categoryParts[[categoryParts count]-2] capitalizedString] stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    } else {
        // No slashes, new Drupal category type.
        cell.textLabel.text = [categoryParts[0] capitalizedString];
    }
    
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    cell.detailTextLabel.text = textString;
    
    // Draw a blank UIImage so that category colours can show through
    CGSize size = CGSizeMake(57, 43);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    id categoryColour = WITH_DEFAULT([self.sectionsArray[indexPath.section][indexPath.row] objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
    [UIColorFromRGB([categoryColour integerValue]) setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    UIImage *blankImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [cell.imageView setImage:blankImage];
    
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

#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    NIAUCategoryViewController *categoryViewController = [segue destinationViewController];
    
    NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
    categoryViewController.category = [self.sectionsArray[selectedIndexPath.section][selectedIndexPath.row] objectForKey:@"name"];
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
