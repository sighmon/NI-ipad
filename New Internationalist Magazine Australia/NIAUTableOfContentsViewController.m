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
        // Initialize the arrays
        self.featureArticles = [[NSMutableArray alloc] init];
        self.agendaArticles = [[NSMutableArray alloc] init];
        self.mixedMediaArticles = [[NSMutableArray alloc] init];
        self.opinionArticles = [[NSMutableArray alloc] init];
        self.alternativesArticles = [[NSMutableArray alloc] init];
        self.regularArticles = [[NSMutableArray alloc] init];
        self.uncategorisedArticles = [[NSMutableArray alloc] init];
        self.sortedCategories = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.cellDictionary = [NSMutableDictionary dictionary];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:ArticlesDidUpdateNotification object:self.issue];
    

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
    
    // Progress view for zip download
    [self.progressView setHidden:YES];
    
    [self sendGoogleAnalyticsStats];
}

- (void)sendGoogleAnalyticsStats
{
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:[NSString stringWithFormat:@"%@ - %@", self.issue.name, self.issue.title]];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createAppView] build]];
}

-(void)publisherReady:(NSNotification *)not
{
    // Clear the array
    
    self.featureArticles = [NSMutableArray array];
    self.agendaArticles = [NSMutableArray array];
    self.mixedMediaArticles = [NSMutableArray array];
    self.opinionArticles = [NSMutableArray array];
    self.alternativesArticles = [NSMutableArray array];
    self.regularArticles = [NSMutableArray array];
    self.uncategorisedArticles = [NSMutableArray array];
    self.sortedCategories = [NSMutableArray array];
    
    // Sort articles into the section arrays
    
    for (int a = 0; a < [self.issue numberOfArticles]; a++) {
        // Test if there's a category that's features
        NIAUArticle *articleToAdd = [self.issue articleAtIndex:a];
        if ([articleToAdd containsCategoryWithSubstring:@"features"]) {
            [self.featureArticles addObject:articleToAdd];
        } else if ([articleToAdd containsCategoryWithSubstring:@"agenda"]) {
            [self.agendaArticles addObject:articleToAdd];
        } else if ([articleToAdd containsCategoryWithSubstring:@"argument"] ||
                   [articleToAdd containsCategoryWithSubstring:@"viewfrom"] ||
                   [articleToAdd containsCategoryWithSubstring:@"steve-parry"] ||
                   [articleToAdd containsCategoryWithSubstring:@"mark-engler"]) {
            [self.opinionArticles addObject:articleToAdd];
        } else if ([articleToAdd containsCategoryWithSubstring:@"media"]) {
            [self.mixedMediaArticles addObject:articleToAdd];
        } else if ([articleToAdd containsCategoryWithSubstring:@"alternatives"]) {
            [self.alternativesArticles addObject:articleToAdd];
        } else if ([articleToAdd containsCategoryWithSubstring:@"columns"] &&
                   ![articleToAdd containsCategoryWithSubstring:@"columns/currents"] &&
                   ![articleToAdd containsCategoryWithSubstring:@"columns/media"] &&
                   ![articleToAdd containsCategoryWithSubstring:@"columns/viewfrom"] &&
                   ![articleToAdd containsCategoryWithSubstring:@"columns/mark-engler"]) {
            [self.regularArticles addObject:articleToAdd];
        } else {
            [self.uncategorisedArticles addObject:articleToAdd];
        }
    }
    
    [self addSectionToSortedCategories:self.featureArticles withName:@"Features"];
    [self addSectionToSortedCategories:self.agendaArticles withName:@"Agenda"];
    [self addSectionToSortedCategories:self.mixedMediaArticles withName:@"Film, Book & Music reviews"];
    [self addSectionToSortedCategories:self.opinionArticles withName:@"Opinion"];
    [self addSectionToSortedCategories:self.alternativesArticles withName:@"Alternatives"];
    [self addSectionToSortedCategories:self.regularArticles withName:@"Regulars"];
    [self addSectionToSortedCategories:self.uncategorisedArticles withName:@"Others"];
    
    int numberOfArticlesCategorised = 0;
    for (int i = 0; i < self.sortedCategories.count; i++) {
        numberOfArticlesCategorised += [[self.sortedCategories[i] objectForKey:@"articles"] count];
        NSLog(@"Category #%d has #%d articles", i, (int)[[self.sortedCategories[i] objectForKey:@"articles"] count]);
    }
    NSLog(@"Number of articles categorised: %d", numberOfArticlesCategorised);
    NSLog(@"Number of articles in this issue: %d", (int)[self.issue numberOfArticles]);
    
    [self showArticles];
}

- (void)addSectionToSortedCategories:(NSArray *)section withName:(NSString *)name
{
    if (section.count > 0) {
        // Sort sections by publish date
        NSArray *sortedArray;
        sortedArray = [section sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            NSDate *first = [(NIAUArticle *)a publication];
            NSDate *second = [(NIAUArticle *)b publication];
            return [first compare:second];
        }];
        
        NSMutableDictionary *sectionDictionary = [NSMutableDictionary dictionary];
        [sectionDictionary setObject:sortedArray forKey:@"articles"];
        [sectionDictionary setObject:name forKey:@"name"];
        [self.sortedCategories addObject:sectionDictionary];
    }
}

- (void)preferredContentSizeChanged:(NSNotification *)aNotification
{
    NSLog(@"Notification received for text change!");
    
    // adjust the layout of the cells
    self.labelNumberAndDate.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.labelEditor.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [self.view setNeedsLayout];
    
    // refresh view...
    // TODO: work out why the titles aren't wrapping at the biggest size.
//    self.cellDictionary = [NSMutableDictionary dictionary];
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
//        NSLog(@"Cell cache hit");
    } else {
//        NSLog(@"\nSection: %@, Index path: %@",[NSNumber numberWithInt:(int)indexPath.section], [NSNumber numberWithInt:(int)indexPath.row]);
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
//    NSLog(@"cellForRow.. %ld",(long)indexPath.row);
    UITableViewCell *cell = [self tableView:tableView cellForHeightForRowAtIndexPath:indexPath];
    [self setupCell:cell atIndexPath:indexPath];
    UILabel *articleTitle = (UILabel *)[cell viewWithTag:101];
    articleTitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    return cell;
}

- (CGSize)calculateCellSize:(UITableViewCell *)cell inTableView:(UITableView *)tableView {
    
    CGSize fittingSize = CGSizeMake(tableView.bounds.size.width, 0);
    CGSize size = [cell.contentView systemLayoutSizeFittingSize:fittingSize];
    
//    int width = size.width;
//    int height = size.height;
    
//    NSLog(@"%@ %ix%i",((UILabel *)[cell viewWithTag:101]).text,width,height);
    
    return size;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [self tableView:tableView cellForHeightForRowAtIndexPath:indexPath];
    
    return [self calculateCellSize:cell inTableView:tableView].height;
}

- (void)setupCellForHeight:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

    NIAUArticle *article = [self.sortedCategories[indexPath.section] objectForKey:@"articles"][indexPath.row];
    
    id teaser = article.teaser;
    teaser = (teaser==[NSNull null]) ? @"" : teaser;
    
    UIImageView *articleImageView = (UIImageView *)[cell viewWithTag:100];
    articleImageView.image = nil;
    // Set background colour to the category colour.
    NSDictionary *firstCategory = article.categories.firstObject;
    id categoryColour = WITH_DEFAULT([firstCategory objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
    articleImageView.backgroundColor = UIColorFromRGB([categoryColour integerValue]);
    
    UILabel *articleTitle = (UILabel *)[cell viewWithTag:101];
    articleTitle.text = article.title;
    articleTitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    
    UILabel *articleTeaser = (UILabel *)[cell viewWithTag:102];
    
    // this is copied from NIAUArticleController, could be DRYer.
    
    // Load CSS from the filesystem
    NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"article-body" withExtension:@"css"];
    NSURL *bootstrapCssURL = [[NSBundle mainBundle] URLForResource:@"bootstrap" withExtension:@"css"];
    
    // Load the article teaser into the attributedText
    NSString *teaserHTML = [NSString stringWithFormat:@"<html> \n"
                                 "<head> \n"
                                 "  <link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                                 "  <link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                                 "</head> \n"
                                 "<body><div class='table-of-contents-article-teaser'>%@</div></body> \n"
                                 "</html>",bootstrapCssURL, cssURL, teaser];
    
    articleTeaser.attributedText = [[NSAttributedString alloc] initWithData:[teaserHTML dataUsingEncoding:NSUTF8StringEncoding]
                                                                    options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                              NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
                                                         documentAttributes:nil
                                                                      error:nil];
}

- (void)setupCell: (UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

    UIImageView *articleImageView = (UIImageView *)[cell viewWithTag:100];
    NIAUArticle *article = [self.sortedCategories[indexPath.section] objectForKey:@"articles"][indexPath.row];
    CGSize thumbSize = CGSizeMake(20,72);
    if (self.tableView.dragging == NO && self.tableView.decelerating == NO) {
        if (articleImageView.image == nil) {
            [article getFeaturedImageThumbWithSize:thumbSize andCompletionBlock:^(UIImage *thumb) {
                if (thumb) {
                    [articleImageView setImage:thumb];
                } else {
//                    [articleImageView.constraints[0] setConstant:20.];
//                    [cell setSeparatorInset:UIEdgeInsetsMake(0, 21., 0, 0)];
                }
            }];
        } else {
            //NSLog(@"Cell has an image.");
        }
    } else {
        UIImage *thumb = [article attemptToGetFeaturedImageThumbFromDiskWithSize:thumbSize];
        if (thumb) {
            [articleImageView setImage:thumb];
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
    [self.tableView reloadRowsAtIndexPaths:visiblePaths withRowAnimation:UITableViewRowAnimationNone];
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
    // Set the cover from the issue cover tapped
    [self.issue getCoverWithCompletionBlock:^(UIImage *img) {
        [self.imageView setAlpha:0.0];
        [self.imageView setImage:img];
        [self.imageView setImage:[NIAUHelper imageWithRoundedCornersSize:10. usingImage:img]];
        [NIAUHelper addShadowToImageView:self.imageView withRadius:3. andOffset:CGSizeMake(0, 2) andOpacity:0.3];
        [UIView animateWithDuration:0.3 animations:^{
            [self.imageView setAlpha:1.0];
        }];

    }];
    
//    self.labelTitle.text = self.issue.title;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMMM yyyy"];
    
    self.labelNumberAndDate.text = [NSString stringWithFormat: @"%@ - %@", self.issue.name, [dateFormatter stringFromDate:self.issue.publication]];
    
    self.labelEditor.text = [NSString stringWithFormat:@"Edited by:\n%@", self.issue.editorsName];
//    self.editorsLetterTextView.text = self.issue.editorsLetter;
    
    // Load CSS from the filesystem
    NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"article-body" withExtension:@"css"];
    
    // Load the editor's letter into the attributedText
    NSString *editorHTML = [NSString stringWithFormat:@"<html> \n"
                            "<head> \n"
                            "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\">"
                            "</head> \n"
                            "<body><div class='table-of-contents-editors-letter'>%@</div></body> \n"
                            "</html>", cssURL, self.issue.editorsLetter];
    
    self.editorsLetterTextView.attributedText = [[NSAttributedString alloc] initWithData:[editorHTML dataUsingEncoding:NSUTF8StringEncoding]
                                                                    options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                              NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
                                                         documentAttributes:nil
                                                                      error:nil];
    NSLog(@"\nScrollView height: %f \neditorsLetter height: %f",self.scrollView.contentSize.height, self.editorsLetterTextView.attributedText.size.height);
//    [self.tableView layoutIfNeeded];
//    [self.editorsLetterTextView setNeedsLayout];
    
    [self.editorImageView setImage:[UIImage imageNamed:@"default_editors_photo"]];
    // Load the real editor's image
    [self.issue getEditorsImageWithCompletionBlock:^(UIImage *img) {
        [self.editorImageView setAlpha:0.0];
        [self.editorImageView setImage:img];
        [UIView animateWithDuration:0.3 animations:^{
            [self.editorImageView setAlpha:1.0];
        }];
    }];
    [NIAUHelper roundedCornersWithRadius:(self.editorImageView.bounds.size.width / 2.) inImageView:self.editorImageView];
}

#pragma mark -
#pragma mark Refresh delegate

-(void)handleRefresh:(UIRefreshControl *)refresh {
    // TODO: set cache object for this issue to nil and refresh
    // TODO: figure out why it crashes inserting new data to tableView.
    [self.cellDictionary removeAllObjects];
    [[NIAUPublisher getInstance] forceDownloadIssues];
    self.issue = [[NIAUPublisher getInstance] issueWithName:self.issue.name];
    [self.issue forceDownloadArticles];
    [self.tableView reloadData];
    [refresh endRefreshing];
}

#pragma mark -
#pragma mark UITextView delegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    // A link was tapped
    // Segue to NIAUWebsiteViewController so users don't leave the app.
    [self performSegueWithIdentifier:@"webLinkTappedFromContents" sender:URL];
    return NO;
}

#pragma mark -
#pragma mark Prepare for Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showImageZoom"])
    {
        // TODO: Load the large version of the image to be zoomed.
        NIAUImageZoomViewController *imageZoomViewController = [segue destinationViewController];
        imageZoomViewController.issueOfOrigin = self.issue;
        
        if ([sender isKindOfClass:[UIImageView class]]) {
            UIImageView *imageTapped = (UIImageView *)sender;
            imageZoomViewController.imageToLoad = imageTapped.image;
        } else {
            imageZoomViewController.imageToLoad = [UIImage imageNamed:@"default_article_image.png"];
        }
    } else if ([[segue identifier] isEqualToString:@"tappedArticle"]) {
        // Load the article tapped.
        
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
        
        NIAUArticleViewController *articleViewController = [segue destinationViewController];
        articleViewController.article = [self.sortedCategories[selectedIndexPath.section] objectForKey:@"articles"][selectedIndexPath.row];
        
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
    NSLog(@"Share tapped!");
    
    NSArray *itemsToShare = @[[NSString stringWithFormat:@"I'm reading '%@' - New Internationalist magazine",self.issue.title], self.imageView.image, self.issue.getWebURL];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [activityController setValue:[NSString stringWithFormat:@"%@ - New Internationalist magazine %@", self.issue.title, self.issue.name] forKey:@"subject"];
    [self presentViewController:activityController animated:YES completion:nil];
}

#pragma mark -
#pragma mark Responding to gestures

- (void)handleSingleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    // Handle image being tapped
    [self performSegueWithIdentifier:@"showImageZoom" sender:gestureRecognizer.view];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download" message:@"Would you like to download this issue for offline reading?" delegate:self cancelButtonTitle:@"No thanks" otherButtonTitles:@"Download", nil];
    [alert show];
}

- (IBAction)handleEditorSingleTap:(UITapGestureRecognizer *)recognizer
{
    // Handle image being tapped
    [self performSegueWithIdentifier:@"showImageZoom" sender:recognizer.view];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Alert view delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
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
}

-(void)startDownload
{
    NSString *zipURL = [[NIAUInAppPurchaseHelper sharedInstance] requestZipURLforRailsID: [self.issue.railsID stringValue]];
    
    if (zipURL) {
        // schedule for issue downloading in background
        NKIssue *newNKIssue = [[NKLibrary sharedLibrary] issueWithName:self.issue.name];
        if(newNKIssue) {
            NSURL *downloadURL = [NSURL URLWithString:zipURL];
            NSURLRequest *req = [NSURLRequest requestWithURL:downloadURL];
            NKAssetDownload *assetDownload = [newNKIssue addAssetWithRequest:req];
            [assetDownload downloadWithDelegate:self];
        }
    } else {
        NSLog(@"No zipURL, so aborting.");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sorry" message:@"It doesn't look like you have a valid subscription or have purchased this issue." delegate:self cancelButtonTitle:@"Oh, okay" otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark - Download delegate

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self.progressView setHidden:YES];
    
    [[NIAUInAppPurchaseHelper sharedInstance] unzipAndMoveFilesForConnection:connection toDestinationURL:destinationURL];
}

- (void)connectionDidResumeDownloading:(NSURLConnection *)connection totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long)expectedTotalBytes
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self.progressView setHidden:NO];
    [self.progressView setProgress:totalBytesWritten/kExpectedTotalBytesFromS3 animated:YES];
}

- (void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long)expectedTotalBytes
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self.progressView setHidden:NO];
    float bytesProgress = totalBytesWritten/kExpectedTotalBytesFromS3;
    [self.progressView setProgress:bytesProgress animated:YES];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self.progressView setHidden:YES];
}

#pragma mark -
#pragma mark Rotation handling

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self updateEditorsLetterTextViewHeightToContent];
    [self.tableView reloadData];
}

@end
