//
//  NIAUTableOfContentsViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 26/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUTableOfContentsViewController.h"
#import "NIAUImageZoomViewController.h"

// Because S3 doesn't give us expectedTotalBytes we use about 21mb
#define kExpectedTotalBytesFromS3 22020096.

float headingFontScale = 1.3;

@interface NIAUTableOfContentsViewController ()

@end

@implementation NIAUTableOfContentsViewController

static NSString *CellIdentifier = @"articleCell";

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Initialize the array
        self.sortedCategories = [[NSArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.cellDictionary = [NSMutableDictionary dictionary];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:ArticlesDidUpdateNotification object:self.issue];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshFromArticle:) name:ArticleDidRefreshNotification object:nil];

    // Add observer for the user changing the text size
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    // Add the data for the view
    [self setupData];
    
    // Set the editorsLetterTextView height to its content.
    [self updateEditorsLetterTextViewHeightToContent];
    self.editorsLetterTextView.scrollsToTop = NO;
    
    [self.issue requestArticles];
    
    // Setup pull-to-refresh for the UIWebView
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:refreshControl];
    
    // User has read the contents page, so clear notifications badge (this also clears the notification from the NotificationCentre on the users phone)
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 0];
//    [[UIApplication sharedApplication] cancelAllLocalNotifications]; // Only if you want to cancel local notifications.
    
    // Tap gestures to download the full zip issue
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [self.imageView addGestureRecognizer:singleTap];
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.imageView addGestureRecognizer:doubleTap];
    
    [singleTap requireGestureRecognizerToFail:doubleTap];
    
    // Tap gesture to delete the issue from cache
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.imageView addGestureRecognizer:longPress];
    
    [singleTap requireGestureRecognizerToFail:longPress];
    
    // Setup two finger swipe to pop to root view
    UISwipeGestureRecognizer *twoFingerSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerSwipe:)];
    twoFingerSwipe.numberOfTouchesRequired = 2;
    
    [self.view addGestureRecognizer:twoFingerSwipe];
    
    // Progress view for zip download
    [self.progressView setHidden:YES];
    
    // Check if user is okay with sending analytics
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if ([standardUserDefaults boolForKey:@"googleAnalytics"] == 1) {
        [self sendGoogleAnalyticsStats];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.alertView) {
        [self.alertView setDelegate:nil];
    }
    // Avoiding crash where user manages to tap to an article before the screen has finished scrolling
    [self.scrollView setDelegate:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)sendGoogleAnalyticsStats
{
    NSString *screenName = [NSString stringWithFormat:@"%@ - %@", self.issue.name, self.issue.title];
    
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

-(void)publisherReady:(NSNotification *)not
{
    // Clear the array
    self.sortedCategories = [NSArray array];
    self.sortedCategories = [self.issue getCategoriesSorted];
    
    [self showArticles];
}

#pragma mark - Dynamic Text

- (void)preferredContentSizeChanged:(NSNotification *)aNotification
{
    NSLog(@"Notification received for text change!");
    
    // adjust the layout of the cells
    self.labelNumberAndDate.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.labelEditor.font = [NIAUHelper scaleFont:UIFontTextStyleHeadline withScale:headingFontScale andiPadSizeCompensation:FALSE];
    [self.view setNeedsLayout];
    
    [self.cellDictionary removeAllObjects];
    [self setupData];
    [self.tableView reloadData];
}

-(void)showArticles
{
    [self.tableView reloadData];
}

- (void)updateEditorsLetterTextViewHeightToContent
{
    // HACK: This magically makes it set the editorsLetterTextView to the correct height
    self.editorsLetterTextViewHeightConstraint.constant = 0;
    
    CGSize size = [self.editorsLetterTextView sizeThatFits: CGSizeMake(self.editorsLetterTextView.frame.size.width, 1.)];
    CGRect frame = self.editorsLetterTextView.frame;
    frame.size.height = size.height;
    self.editorsLetterTextViewHeightConstraint.constant = size.height;
    [self.editorsLetterTextView setNeedsUpdateConstraints];
    [self.editorsLetterTextView setNeedsLayout];
    
    [self.scrollView setNeedsLayout];
    [self.scrollView layoutIfNeeded];
    
    [self updateFooterViewHight];
    
}

- (void)updateFooterViewHight
{
    // Set the footer size
    CGSize size = [self.editorsLetterTextView sizeThatFits: CGSizeMake(self.editorsLetterTextView.frame.size.width, 1.)];
    CGRect frame = self.editorsLetterTextView.frame;
    frame.size.height = size.height + self.editorImageView.frame.size.height + self.labelEditor.frame.size.height + 40;
    self.tableViewFooterView.frame = frame;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sortedCategories.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.sortedCategories[section] objectForKey:@"articles"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [self.sortedCategories[section] objectForKey:@"name"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSMutableDictionary *cellSectionDictionary = [NSMutableDictionary dictionary];
    id cell = [[self.cellDictionary objectForKey:[NSNumber numberWithInt:(int)indexPath.section]] objectForKey:[NSNumber numberWithInt:(int)indexPath.row]];
    if (cell != nil) {
//        DebugLog(@"Cell cache hit");
    } else {
//        DebugLog(@"\nSection: %@, Index path: %@",[NSNumber numberWithInt:(int)indexPath.section], [NSNumber numberWithInt:(int)indexPath.row]);
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        [self setupCellForHeight:cell atIndexPath:indexPath];
        [cellSectionDictionary setObject:cell forKey:[NSNumber numberWithInt:(int)indexPath.row]];
        if ([self.cellDictionary objectForKey:[NSNumber numberWithInt:(int)indexPath.section]]) {
            [[self.cellDictionary objectForKey:[NSNumber numberWithInt:(int)indexPath.section]] setObject:cell forKey:[NSNumber numberWithInt:(int)indexPath.row]];
        } else {
            [self.cellDictionary setObject:cellSectionDictionary forKey:[NSNumber numberWithInt:(int)indexPath.section]];
        }
    }
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    DebugLog(@"cellForRow.. %ld",(long)indexPath.row);
    UITableViewCell *cell = [self tableView:tableView cellForHeightForRowAtIndexPath:indexPath];
    [self setupCell:cell atIndexPath:indexPath];
    UILabel *articleTitle = (UILabel *)[cell viewWithTag:101];
    articleTitle.font = [NIAUHelper scaleFont:UIFontTextStyleHeadline withScale:headingFontScale andiPadSizeCompensation:FALSE];
    return cell;
}

- (CGSize)calculateCellSize:(UITableViewCell *)cell inTableView:(UITableView *)tableView {
    
    CGSize fittingSize = CGSizeMake(tableView.bounds.size.width, 0);
    CGSize size = [cell.contentView systemLayoutSizeFittingSize:fittingSize];
    
    // HACK: on the iPad the cell height isn't quite big enough to fit the full heading. So adding this slop. :-/
    size.height += 5;
    
//    DebugLog(@"%@ - %@ - %@",((UILabel *)[cell viewWithTag:101]).text, NSStringFromCGSize(size), NSStringFromCGSize(cell.frame.size));
    
    return size;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [self tableView:tableView cellForHeightForRowAtIndexPath:indexPath];
    
    return [self calculateCellSize:cell inTableView:tableView].height;
}

- (void)setupCellForHeight:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

    NIAUArticle *article = [self.sortedCategories[indexPath.section] objectForKey:@"articles"][indexPath.row];
    
    id teaser = article.teaser;
    if (teaser == nil || teaser == [NSNull null]) {
        teaser = @"";
    }
    
    UIImageView *articleImageView = (UIImageView *)[cell viewWithTag:100];
    articleImageView.image = nil;
    
    // Set background colour to the category colour.
    NSDictionary *firstCategory = article.categories.firstObject;
    id categoryColour = WITH_DEFAULT([firstCategory objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
    
    // Hmmm.. those colours don't make much sense on the Table of Contents,
    // Use nice gradients of green maybe?
    
    NSString *sectionName = [self.sortedCategories[indexPath.section] objectForKey:@"name"];
    if ([sectionName rangeOfString:@"features" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // use Features colour
        categoryColour = [NSNumber numberWithInt:0x69a33b];
        
    } else if ([sectionName rangeOfString:@"exclusive" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // use Digital exclusive colour
        categoryColour = [NSNumber numberWithInt:0x77b447];
        
    } else if ([sectionName rangeOfString:@"video" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // use Videos colour
        categoryColour = [NSNumber numberWithInt:0x7dbf49];
        
    } else if ([sectionName rangeOfString:@"agenda" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // use Agenda colour
        categoryColour = [NSNumber numberWithInt:0x8ecb5d];
        
    } else if ([sectionName rangeOfString:@"currents" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // use Agenda colour
        categoryColour = [NSNumber numberWithInt:0x8ecb5d];
        
    } else if ([sectionName rangeOfString:@"reviews" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // use Reviews colour
        categoryColour = [NSNumber numberWithInt:0xa0d377];
        
    } else if ([sectionName rangeOfString:@"opinion" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // use Opinion colour
        categoryColour = [NSNumber numberWithInt:0xcbecb1];
        
    } else if ([sectionName rangeOfString:@"regulars" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // use Regulars colour
        categoryColour = [NSNumber numberWithInt:0xdef6cb];
        
    } else if ([sectionName rangeOfString:@"blogs" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        // use Blogs colour
        categoryColour = [NSNumber numberWithInt:0xe6f5da];
        
    } else {
        // Unknown section, leave as it is
        DebugLog(@"ERROR: unknown category colour for category %@", sectionName);
    }
    
    articleImageView.backgroundColor = UIColorFromRGB([categoryColour integerValue]);
    
    UILabel *articleTitle = (UILabel *)[cell viewWithTag:101];
    articleTitle.text = article.title;
    articleTitle.font = [NIAUHelper scaleFont:UIFontTextStyleHeadline withScale:headingFontScale andiPadSizeCompensation:FALSE];
    
    UILabel *articleTeaser = (UILabel *)[cell viewWithTag:102];
    
    // this is copied from NIAUArticleController, could be DRYer.
    
    // Load CSS from the filesystem
    NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"article-body" withExtension:@"css"];
    NSURL *bootstrapCssURL = [[NSBundle mainBundle] URLForResource:@"bootstrap" withExtension:@"css"];
    
    // Set the font size percentage from Dynamic Type
    NSString *fontSizePercentage = [NIAUHelper fontSizePercentage];
    
    // Load the article teaser into the attributedText
    NSString *teaserHTML = [NSString stringWithFormat:@"<html> \n"
                                 "<head> \n"
                                 "  <link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                                 "  <link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                                 "</head> \n"
                                 "<body style='font-size: %@'><div class='table-of-contents-article-teaser'>%@</div></body> \n"
                                 "</html>",bootstrapCssURL, cssURL, fontSizePercentage, teaser];
    
    articleTeaser.attributedText = [[NSAttributedString alloc] initWithData:[teaserHTML dataUsingEncoding:NSUTF8StringEncoding]
                                                                    options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                              NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
                                                         documentAttributes:nil
                                                                      error:nil];
    // This call doesn't work for iPhone 4S.
    // Tries to fix the extra space in the UITableView under the teaser.
//    articleTeaser.preferredMaxLayoutWidth = cell.frame.size.width;
}

- (void)setupCell: (UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

    __block UIImageView *articleImageView = (UIImageView *)[cell viewWithTag:100];
    NIAUArticle *article = [self.sortedCategories[indexPath.section] objectForKey:@"articles"][indexPath.row];
    CGSize thumbSize = CGSizeMake(120,cell.frame.size.height);
    if (self.tableView.dragging == NO && self.tableView.decelerating == NO) {
        if (articleImageView.image == nil) {
            [article getFeaturedImageThumbWithSize:thumbSize andCompletionBlock:^(UIImage *thumb) {
                if (thumb) {
                    [NIAUHelper fadeInImage:thumb intoImageView:articleImageView];
                } else {
                    // If the article has an article image, get it.
                    NSDictionary *firstImage = [article firstImage];
                    if ([firstImage count] > 0) {
                        [article getFirstImageWithID:[[firstImage objectForKey:@"id"] stringValue] andSize:thumbSize withCompletionBlock:^(UIImage *img) {
                            if (img) {
                                [NIAUHelper fadeInImage:img intoImageView:articleImageView];
                            }
                        }];
                    }
                }
            }];
        } else {
            //DebugLog(@"Cell has an image.");
        }
    } else {
        UIImage *thumb = [article attemptToGetFeaturedImageThumbFromDiskWithSize:thumbSize];
        if (thumb) {
            [NIAUHelper fadeInImage:thumb intoImageView:articleImageView];
        } else {
//            [articleImageView.constraints[0] setConstant:20.];
//            [cell setSeparatorInset:UIEdgeInsetsMake(0, 21., 0, 0)];
        }
    }
}

// -------------------------------------------------------------------------------
//	loadImagesForOnscreenRows
//  This method is used in case the user scrolled into a set of cells that don't
//  have their featured images yet.
// -------------------------------------------------------------------------------
- (void)loadImagesForOnscreenRows
{
    NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];
    for (NSIndexPath *indexPath in visiblePaths) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self setupCell:cell atIndexPath:indexPath];
    }
    // TODO: Check to see if not calling reload has any implications
//    [self.tableView reloadRowsAtIndexPaths:visiblePaths withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UIScrollViewDelegate

// -------------------------------------------------------------------------------
//	scrollViewDidEndDragging:willDecelerate:
//  Load images for all onscreen rows when scrolling is finished.
// -------------------------------------------------------------------------------
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
	{
        [self loadImagesForOnscreenRows];
    }
}

// -------------------------------------------------------------------------------
//	scrollViewDidEndDecelerating:
// -------------------------------------------------------------------------------
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self loadImagesForOnscreenRows];
}


#pragma mark -
#pragma mark Setup Data

- (void)setupData
{
    // Check if the issue is available and display defaults if not.
    if (self.issue) {
        // Set the cover from the issue cover tapped
        [self.issue getCoverWithCompletionBlock:^(UIImage *img) {
            [self.imageView setAlpha:0.0];
            [self.imageView layoutIfNeeded];
            [self.imageView setImage:[NIAUHelper imageWithRoundedCornersSize:10. usingImage:img]];
            [NIAUHelper addShadowToImageView:self.imageView withRadius:3. andOffset:CGSizeMake(0, 2) andOpacity:0.3];
            [UIView animateWithDuration:0.3 animations:^{
                [self.imageView setAlpha:1.0];
            }];
            
        }];
        
        //    self.labelTitle.text = self.issue.title;
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        [dateFormatter setDateFormat:@"MMMM yyyy"];
        
        self.labelNumberAndDate.text = [NSString stringWithFormat: @"%@ - %@", self.issue.name, [dateFormatter stringFromDate:self.issue.publication]];
        
        self.labelEditor.text = [NSString stringWithFormat:@"Edited by:\n%@", self.issue.editorsName];
        
        // Load CSS from the filesystem
        NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"article-body" withExtension:@"css"];
        NSURL *bootstrapCssURL = [[NSBundle mainBundle] URLForResource:@"bootstrap" withExtension:@"css"];
        
        // Set the font size percentage from Dynamic Type
        NSString *fontSizePercentage = [NIAUHelper fontSizePercentage];
        
        // Load the editor's letter into the attributedText
        NSString *editorHTML = [NSString stringWithFormat:@"<html> \n"
                                "<head> \n"
                                "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                                "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                                "</head> \n"
                                "<body style='font-size: %@'><div class='table-of-contents-editors-letter'>%@</div></body> \n"
                                "</html>", bootstrapCssURL, cssURL, fontSizePercentage, self.issue.editorsLetter];
        
        self.editorsLetterTextView.attributedText = [[NSAttributedString alloc] initWithData:[editorHTML dataUsingEncoding:NSUTF8StringEncoding]
                                                                                     options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                                               NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
                                                                          documentAttributes:nil
                                                                                       error:nil];
        DebugLog(@"\nScrollView height: %f \neditorsLetter height: %f",self.scrollView.contentSize.height, self.editorsLetterTextView.attributedText.size.height);
        //    [self.tableView layoutIfNeeded];
        //    [self.editorsLetterTextView setNeedsLayout];
        [self.editorsLetterTextView layoutIfNeeded];
        
        [self.editorImageView setImage:[UIImage imageNamed:@"default_editors_photo"]];
        // Load the real editor's image
        [self.issue getEditorsImageWithCompletionBlock:^(UIImage *img) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.editorImageView setAlpha:0.0];
                [self.editorImageView setImage:img];
                [UIView animateWithDuration:0.3 animations:^{
                    [self.editorImageView setAlpha:1.0];
                }];
            });
        }];
        [self.editorImageView layoutIfNeeded];
        [NIAUHelper roundedCornersWithRadius:(self.editorImageView.bounds.size.width / 2.) inImageView:self.editorImageView];
        
        // If help is enabled, show help alert
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"showHelp"] == 1) {
            [NIAUHelper showHelpAlertWithMessage:@"If you want to download the entire issue, double tap the cover." andDelegate:self];
        }
    } else {
        // self.issue isn't around... set defaults
        
        // Cover
//        [self.imageView setAlpha:0.0];
//        [self.imageView setImage:[NIAUHelper imageWithRoundedCornersSize:10. usingImage:[UIImage imageNamed:@"default_cover.png"]]];
//        [NIAUHelper addShadowToImageView:self.imageView withRadius:3. andOffset:CGSizeMake(0, 2) andOpacity:0.3];
//        [UIView animateWithDuration:0.3 animations:^{
//            [self.imageView setAlpha:1.0];
//        }];
        
        // Editor's image
        [self.editorImageView setAlpha:0.0];
        [self.editorImageView setImage:[UIImage imageNamed:@"default_editors_photo.png"]];
        [UIView animateWithDuration:0.3 animations:^{
            [self.editorImageView setAlpha:1.0];
        }];
        
        self.labelEditor.text = @"Uh oh!";
        
        // Editor's letter
        self.editorsLetterTextView.text = @"Sorry, we can't load this issue.. if you'd like to email to let us know what happened, that'd be great!\n\ndesign@newint.com.au";
        
        self.labelNumberAndDate.text = @"";
    }
}

#pragma mark -
#pragma mark Refresh delegate

-(void)handleRefresh:(UIRefreshControl *)refresh {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // set cache object for this issue to nil and refresh
        [self.cellDictionary removeAllObjects];
        [[NIAUPublisher getInstance] forceDownloadIssues];
        self.issue = [[NIAUPublisher getInstance] issueWithName:self.issue.name];
        [self.issue forceDownloadArticles];
        // Reset the sortedCategories cache
        self.sortedCategories = [self.issue getCategoriesSortedStartingAt:@"net"];
        // Reset the sortedArticles cache
        [self.issue getArticlesSortedStartingAt:@"net"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
            [refresh endRefreshing];
        });
    });
}

-(void)refreshFromArticle:(NSNotification *)notification
{
    [self handleRefresh:[[notification userInfo] objectForKey:@"refresh"]];
}

#pragma mark -
#pragma mark UITextView delegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    // A link was tapped
    
    // Check to see if the link is an internal link or external link by looking for http?
    
    if ([NIAUHelper validArticleInURL:URL]) {
        // Build article segue from URL and set sender to NIAUArticle
        
        NSString *articleIDFromURL = [[URL pathComponents] lastObject];
        NSNumber *articleID = [NSNumber numberWithInt:(int)[articleIDFromURL integerValue]];
        NSString *issueIDFromURL = [[URL pathComponents] objectAtIndex:2];
        NSNumber *issueID = [NSNumber numberWithInt:(int)[issueIDFromURL integerValue]];
        NSArray *arrayOfIssues = [NIAUIssue issuesFromFilesystem];
        NSUInteger issueIndexPath = [arrayOfIssues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return ([[obj railsID] isEqualToNumber:issueID]);
        }];
        if (issueIndexPath != NSNotFound) {
            NIAUIssue *issueToLoad = [arrayOfIssues objectAtIndex:issueIndexPath];
            NIAUArticle *articleToLoad = [NIAUArticle articleFromCacheWithIssue:issueToLoad andId:articleID];
            if (articleToLoad) {
                // Segue to that article
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self performSegueWithIdentifier:@"tappedArticle" sender:articleToLoad];
                });
            } else {
                // Can't find the article, pop up a UIAlertView?
                self.alertView = [[UIAlertView alloc] initWithTitle:@"Bad link, sorry!" message:@"It looks like we can't find that article, sorry!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [self.alertView show];
            }
        } else {
            // Can't find that issue.. UIAlertView?
            self.alertView = [[UIAlertView alloc] initWithTitle:@"Bad link, sorry!" message:@"It looks like we can't find that issue, sorry!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [self.alertView show];
        }
        
        // Return NO so that the UITextView doesn't load the URL. :-)
        return NO;
    } else if ([NIAUHelper validIssueInURL:URL]) {
        // Build issue segue from URL and set sender to NIAUIssue
        
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:[NSBundle mainBundle]];
        
        NIAUTableOfContentsViewController *issueViewController = [storyboard instantiateViewControllerWithIdentifier:@"issue"];
        
        NSString *issueIDFromURL = [[URL pathComponents] objectAtIndex:2];
        NSNumber *issueID = [NSNumber numberWithInt:(int)[issueIDFromURL integerValue]];
        NSArray *arrayOfIssues = [NIAUIssue issuesFromFilesystem];
        NSUInteger issueIndexPath = [arrayOfIssues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return ([[obj railsID] isEqualToNumber:issueID]);
        }];
        if (issueIndexPath != NSNotFound) {
            NIAUIssue *issueToLoad = [arrayOfIssues objectAtIndex:issueIndexPath];
            // Push the issueViewController - would be nice to segue to self, but not possible.
            issueViewController.issue = issueToLoad;
            [self.navigationController pushViewController:issueViewController animated:YES];
        } else {
            // Can't find that issue.. UIAlertView?
            self.alertView = [[UIAlertView alloc] initWithTitle:@"Bad link, sorry!" message:@"It looks like we can't find that issue, sorry!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [self.alertView show];
        }
        
        // Return NO so that the UITextView doesn't load the URL. :-)
        return NO;
    } else {
        // Segue to NIAUWebsiteViewController so users don't leave the app.
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self performSegueWithIdentifier:@"webLinkTappedFromContents" sender:URL];
        });
        
        // Return NO so that the UITextView doesn't load the URL. :-)
        return NO;
    }
}

#pragma mark -
#pragma mark Prepare for Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showImageZoom"])
    {
        // Load the large version of the image to be zoomed.
        NIAUImageZoomViewController *imageZoomViewController = [segue destinationViewController];
        imageZoomViewController.issueOfOrigin = self.issue;
        
        if ([sender isKindOfClass:[UIImageView class]]) {
            UIImageView *imageTapped = (UIImageView *)sender;
            imageZoomViewController.imageToLoad = imageTapped.image;
        } else {
            imageZoomViewController.imageToLoad = [UIImage imageNamed:@"default_article_image.png"];
        }
    } else if ([[segue identifier] isEqualToString:@"tappedArticle"]) {
        if ([sender isKindOfClass:[NIAUArticle class]]) {
            // Segue to Article link from Editor's letter
            NIAUArticleViewController *articleViewController = [segue destinationViewController];
            articleViewController.article = sender;
            
        } else {
            // Load the article tapped from UITableView.
            
            NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
            
            NIAUArticleViewController *articleViewController = [segue destinationViewController];
            articleViewController.article = [self.sortedCategories[selectedIndexPath.section] objectForKey:@"articles"][selectedIndexPath.row];
        }
        
    } else if ([[segue identifier] isEqualToString:@"tappedIssue"]) {
        // Segue to Issue link from Editor's letter
        NIAUTableOfContentsViewController *issueViewController = [segue destinationViewController];
        issueViewController.issue = sender;
        
    } else if ([[segue identifier] isEqualToString:@"webLinkTappedFromContents"]) {
        // Send the weblink
        NIAUWebsiteViewController *websiteViewController = [segue destinationViewController];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:sender];
        websiteViewController.linkToLoad = request;
        websiteViewController.issue = self.issue;
    }
}

#pragma mark -
#pragma mark Social sharing

- (IBAction)shareActionTapped:(id)sender
{
    DebugLog(@"Share tapped!");
    
    UIImage *coverToShare;
    
    // To prevent a crash if the cover hasn't loaded yet.
    if (self.imageView.image) {
        coverToShare = self.imageView.image;
    } else {
        coverToShare = [UIImage imageNamed:@"default_cover@2x.png"];
    }

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    [dateFormatter setDateFormat:@"MMMM yyyy"];
    NSString *issueDate = [NSString stringWithFormat: @"%@", [dateFormatter stringFromDate: self.issue.publication]];

    NSArray *itemsToShare = @[[NSString stringWithFormat:@"%@ - New Internationalist magazine %@", self.issue.title, issueDate], coverToShare, self.issue.getWebURL];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [activityController setValue:[NSString stringWithFormat:@"%@ - New Internationalist magazine %@", self.issue.title, self.issue.name] forKey:@"subject"];
    
    // Avoid the iOS 8 iPad crash
    if (IS_IPAD() && SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        activityController.popoverPresentationController.barButtonItem = sender;
    };
    
    // HACK: to fix UIActivityViewController bar button tintColor
    [[UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil] setTintColor:self.view.tintColor];
    [[UINavigationBar appearance] setTintColor:self.view.tintColor];
    
    [self presentViewController:activityController animated:YES completion:nil];
}

#pragma mark -
#pragma mark Responding to gestures

- (void)handleSingleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    // Handle image being tapped
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self performSegueWithIdentifier:@"showImageZoom" sender:gestureRecognizer.view];
    });
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    self.alertView = [[UIAlertView alloc] initWithTitle:@"Download" message:@"Would you like to download this issue for offline reading?" delegate:self cancelButtonTitle:@"No thanks" otherButtonTitles:@"Download", nil];
    [self.alertView show];
}

- (void)handleLongPress:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        self.alertView = [[UIAlertView alloc] initWithTitle:@"Delete" message:@"Would you like to remove this issue from your cache to free up some disk space?" delegate:self cancelButtonTitle:@"No thanks" otherButtonTitles:@"Yes please", nil];
        [self.alertView show];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)handleTwoFingerSwipe:(UISwipeGestureRecognizer *)swipe
{
    // Pop back to the root view controller on triple tap
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (IBAction)handleEditorSingleTap:(UITapGestureRecognizer *)recognizer
{
    // Handle image being tapped
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self performSegueWithIdentifier:@"showImageZoom" sender:recognizer.view];
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Alert view delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Download"]) {
        switch (buttonIndex) {
            case 0:
                // Cancel pressed
                break;
            case 1:
                // Download pressed
                [self startDownload];
                break;
            default:
                break;
        }
    } else if ([alertView.title isEqualToString:@"Delete"]) {
        switch (buttonIndex) {
            case 0:
                // Cancel pressed
                break;
            case 1:
                // Delete pressed
                [self.issue clearCache];
                break;
            default:
                break;
        }
    } else if ([alertView.title isEqualToString:@"Sorry"]) {
        switch (buttonIndex) {
            case 0:
                // Cancel pressed, do nothing
                break;
            case 1:
                // Segue to subscription
                [self performSegueWithIdentifier:@"sorryAlertToSubscribe" sender:nil];
                break;
            case 2:
                // Segue to log-in
                [self performSegueWithIdentifier:@"sorryAlertToLogin" sender:nil];
                break;
            default:
                break;
        }
    } else if ([alertView.title isEqualToString:[NIAUHelper helpAlertTitle]]) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        switch (buttonIndex) {
            case 0:
                // Cancel pressed, don't show help again
                [userDefaults setBool:FALSE forKey:@"showHelp"];
                [userDefaults synchronize];
                break;
            case 1:
                // Thanks pressed, do nothing
                break;
            default:
                break;
        }
    }
}

-(void)startDownload
{
    // Check for internet access
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus netStatus = [reachability currentReachabilityStatus];
    
    if (netStatus == NotReachable) {
        // Ask them to turn on wifi or get internet access.
        self.alertView = [[UIAlertView alloc] initWithTitle:@"Internet access?" message:@"It doesn't seem like you have internet access, turn it on to subscribe or download this article." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [self.alertView show];
    } else {
        // Has internet..
        NSString *zipURL = [[NIAUInAppPurchaseHelper sharedInstance] requestZipURLforRailsID: [self.issue.railsID stringValue]];
        
        if (zipURL) {
            // schedule for issue downloading in background
            if(self.issue) {
                NSURL *downloadURL = [NSURL URLWithString:zipURL];
                NSURLRequest *request = [NSURLRequest requestWithURL:downloadURL];
                NSURLSession *session = [NSURLSession sharedSession];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                    [self.progressView setHidden:NO];
                    [self.progressView setProgress:1.0 animated:true];
                });
                [[session downloadTaskWithRequest:request completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    if (error) {
                        DebugLog(@"Download error: %@", error);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                            [self.progressView setHidden:YES];
                        });
                    }
                    DebugLog(@"Download succeeded: %@", self.issue.name);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                        [self.progressView setHidden:YES];
                    });

                    [[NIAUInAppPurchaseHelper sharedInstance] unzipAndMoveFilesForIssue: self.issue.railsID toDestinationURL:location];
                }] resume];
            }
        } else {
            NSLog(@"No zipURL, so aborting.");
            
            self.alertView = [[UIAlertView alloc] initWithTitle:@"Sorry" message:@"It doesn't look like you're a subscriber or if you are, perhaps you haven't logged in yet. What would you like to do?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Subscribe", @"Log-in", nil];
            [self.alertView show];
        }
    }
}

#pragma mark -
#pragma mark Rotation handling

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // Code to prepare for transition
        
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // Handle change
        [self updateEditorsLetterTextViewHeightToContent];
        [self.tableView reloadData];
    }];
}

@end
