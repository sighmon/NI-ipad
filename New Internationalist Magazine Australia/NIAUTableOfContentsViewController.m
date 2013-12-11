//
//  NIAUTableOfContentsViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 26/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUTableOfContentsViewController.h"
#import "NIAUImageZoomViewController.h"

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
        self.categoriesArray = [[NSMutableArray alloc] init];
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
}

-(void)publisherReady:(NSNotification *)not
{
    // Clear the array
    self.categoriesArray = [NSMutableArray array];
    
    // TODO: Sort articles into self.categoriesArray
    
    for (int a = 0; a < [self.issue numberOfArticles]; a++) {
        for (int c = 0; c < [[self.issue articleAtIndex:a].categories count]; c++) {
            // Add categories to the categories array only if they're unique
            NSDictionary *objectToAdd = [self.issue articleAtIndex:a].categories[c];
            NSUInteger categoryIndex = [self.categoriesArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [[obj objectForKey:@"name"] isEqualToString:[objectToAdd objectForKey:@"name"]];
            }];
            if (categoryIndex == NSNotFound) {
                [self.categoriesArray addObject:objectToAdd];
            }
        }
    }
    
    // Sort the categoriesArray alphabetically
    [self.categoriesArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDictionary *d1 = obj1, *d2 = obj2;
        return [[d1 objectForKey:@"name"] caseInsensitiveCompare:[d2 objectForKey:@"name"]];
    }];
    
    // TODO: FINISH sorting the categoriesArray as Rails site does
    
    NSMutableArray *sortedCategoriesArray = [NSMutableArray array];
    
    for (int c = 0; c < [self.categoriesArray count]; c++) {
        NSDictionary *objectToAdd = self.categoriesArray[c];
        NSUInteger categoryIndex = [self.categoriesArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [[obj objectForKey:@"name"] isEqualToString:@"/features/"];
        }];
        if (categoryIndex) {
            [sortedCategoriesArray addObject:objectToAdd];
        }
        categoryIndex = false;
        categoryIndex = [self.categoriesArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [[obj objectForKey:@"name"] isEqualToString:@"/sections/agenda/"];
        }];
        if (categoryIndex) {
            [sortedCategoriesArray addObject:objectToAdd];
        }
    }
    
    // Features (keynote)
    // Agenda
    // Mixed Media
    // Opinion
    // Regulars
    
    [self showArticles];
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
    
    [self.scrollView setNeedsLayout];
    [self.scrollView layoutIfNeeded];
    
    self.editorsLetterTextViewHeightConstraint.constant = self.editorsLetterTextView.contentSize.height;
    
    // TODO: Get this right for the iPhone view.
    
    [self updateFooterViewHight];
    
//    self.tableViewFooterView.frame = CGRectMake(self.tableViewFooterView.frame.origin.x, self.tableViewFooterView.frame.origin.y, self.editorsLetterTextView.attributedText.size.width, self.editorsLetterTextView.attributedText.size.height *5);
}

- (void)updateFooterViewHight
{
    // Set the footer size
    CGSize size = [self.editorsLetterTextView sizeThatFits: CGSizeMake(320., 1.)];
    CGRect frame = self.editorsLetterTextView.frame;
    frame.size.height = size.height + self.editorImageView.frame.size.height + self.labelEditor.frame.size.height + 40;
    self.tableViewFooterView.frame = frame;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.issue numberOfArticles];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    id cell = [self.cellDictionary objectForKey:[NSNumber numberWithInt:indexPath.row]];
    if (cell != nil) {
//        NSLog(@"Cell cache hit");
    } else {
//        NSLog(@"Index path: %@",[NSNumber numberWithInt:indexPath.row]);
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        [self setupCellForHeight:cell atIndexPath:indexPath];
        [self.cellDictionary setObject:cell forKey:[NSNumber numberWithInt:indexPath.row]];
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

- (void)setupCellForHeight: (UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

    id teaser = [self.issue articleAtIndex:indexPath.row].teaser;
    teaser = (teaser==[NSNull null]) ? @"" : teaser;
    
    UIImageView *articleImageView = (UIImageView *)[cell viewWithTag:100];
    articleImageView.image = nil;
    // Set background colour to the category colour.
    NSDictionary *firstCategory = [self.issue articleAtIndex:indexPath.row].categories.firstObject;
    id categoryColour = WITH_DEFAULT([firstCategory objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
    articleImageView.backgroundColor = UIColorFromRGB([categoryColour integerValue]);
    
    UILabel *articleTitle = (UILabel *)[cell viewWithTag:101];
    articleTitle.text = [self.issue articleAtIndex:indexPath.row].title;
    articleTitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    
    UILabel *articleTeaser = (UILabel *)[cell viewWithTag:102];
    
    // this is copied from NIAUArticleController, could be DRYer.
    
    // Load CSS from the filesystem
    NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"article-body" withExtension:@"css"];
    
    // Load the article teaser into the attributedText
    NSString *teaserHTML = [NSString stringWithFormat:@"<html> \n"
                                 "<head> \n"
                                 "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\">"
                                 "</head> \n"
                                 "<body><div class='table-of-contents-article-teaser'>%@</div></body> \n"
                                 "</html>", cssURL, teaser];
    
    articleTeaser.attributedText = [[NSAttributedString alloc] initWithData:[teaserHTML dataUsingEncoding:NSUTF8StringEncoding]
                                                                    options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                              NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
                                                         documentAttributes:nil
                                                                      error:nil];
}

- (void)setupCell: (UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

    UIImageView *articleImageView = (UIImageView *)[cell viewWithTag:100];
    NIAUArticle *article = [self.issue articleAtIndex:indexPath.row];
    CGSize thumbSize = CGSizeMake(57,72);
    if (self.tableView.dragging == NO && self.tableView.decelerating == NO) {
        if (articleImageView.image == nil) {
            [article getFeaturedImageThumbWithSize:thumbSize andCompletionBlock:^(UIImage *thumb) {
                [articleImageView setImage:thumb];
            }];
        } else {
            //NSLog(@"Cell has an image.");
        }
    } else {
        UIImage *thumb = [article attemptToGetFeaturedImageThumbFromDiskWithSize:thumbSize];
        if(thumb) {
            [articleImageView setImage:thumb];
        }
    }
}

// -------------------------------------------------------------------------------
//	loadImagesForOnscreenRows
//  This method is used in case the user scrolled into a set of cells that don't
//  have their app icons yet.
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
    
    // Load the article teaser into the attributedText
    NSString *teaserHTML = [NSString stringWithFormat:@"<html> \n"
                            "<head> \n"
                            "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\">"
                            "</head> \n"
                            "<body><div class='table-of-contents-editors-letter'>%@</div></body> \n"
                            "</html>", cssURL, self.issue.editorsLetter];
    
    self.editorsLetterTextView.attributedText = [[NSAttributedString alloc] initWithData:[teaserHTML dataUsingEncoding:NSUTF8StringEncoding]
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
    [self applyRoundMask:self.editorImageView];
}

- (void)applyRoundMask:(UIImageView *)imageView
{
    // Draw a round mask for images.. i.e. the editor's photo
    imageView.layer.masksToBounds = YES;
    imageView.layer.cornerRadius = self.editorImageView.bounds.size.width / 2.;
}

- (void)addShadowToImageView:(UIImageView *)imageView
{
    // Shadow for any images, i.e. the cover
    imageView.layer.shadowColor = [UIColor blackColor].CGColor;
    imageView.layer.shadowOffset = CGSizeMake(0, 2);
    imageView.layer.shadowOpacity = 0.3;
    imageView.layer.shadowRadius = 3.0;
    imageView.clipsToBounds = NO;
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
#pragma mark Prepare for Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showImageZoom"])
    {
        // TODO: Load the large version of the image to be zoomed.
        NIAUImageZoomViewController *imageZoomViewController = [segue destinationViewController];
        
        if ([sender isKindOfClass:[UIImageView class]]) {
            UIImageView *imageTapped = (UIImageView *)sender;
            imageZoomViewController.imageToLoad = imageTapped.image;
        } else {
            imageZoomViewController.imageToLoad = [UIImage imageNamed:@"default_article_image.png"];
        }
    } else if ([[segue identifier] isEqualToString:@"tappedArticle"])
    {
        // Load the article tapped.
        
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
        
        NIAUArticleViewController *articleViewController = [segue destinationViewController];
        articleViewController.article = [self.issue articleAtIndex:selectedIndexPath.row];
        
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

- (IBAction)handleCoverSingleTap:(UITapGestureRecognizer *)recognizer
{
    // Handle image being tapped
    [self performSegueWithIdentifier:@"showImageZoom" sender:recognizer.view];
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
