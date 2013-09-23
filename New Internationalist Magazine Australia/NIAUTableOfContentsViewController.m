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

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.cellDictionary = [NSMutableDictionary dictionary];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:ArticlesDidUpdateNotification object:self.issue];
    
    [self.issue requestArticles];
    
    // Add the data for the view
    [self setupData];
    
    // Set the editorsLetterTextView height to its content.
//    [self updateEditorsLetterTextViewHeightToContent];
    
    // Set the scrollView content height to the editorsLetterTextView.
//    [self updateScrollViewContentHeight];
}

-(void)publisherReady:(NSNotification *)not
{
    [self showArticles];
}

-(void)showArticles
{
    [self.tableView reloadData];
//    [self updateEditorsLetterTextViewHeightToContent];
//    [self updateScrollViewContentHeight];
}

- (void)updateEditorsLetterTextViewHeightToContent
{
    CGFloat editorsLetterTextViewHeight = self.editorsLetterTextView.contentSize.height;
    
    // now set the height constraint accordingly
    
    [UIView animateWithDuration:0.25 animations:^{
        self.editorsLetterTextViewHeightConstraint.constant = editorsLetterTextViewHeight;
        [self.view needsUpdateConstraints];
    }];
}

- (void)updateScrollViewContentHeight
{
    CGRect contentRect = CGRectZero;
    for (UIView *view in self.scrollView.subviews) {
        contentRect = CGRectUnion(contentRect, view.frame);
    }
    self.scrollView.contentSize = contentRect.size;
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
    articleImageView.image = [UIImage imageNamed:@"default_article_image_table_view.png"];
    // Set background colour to the category colour.
    NSDictionary *firstCategory = [self.issue articleAtIndex:indexPath.row].categories.firstObject;
    id categoryColour = [firstCategory objectForKey:@"colour"];
    #define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
    cell.backgroundColor = UIColorFromRGB([categoryColour integerValue]);
    
    UILabel *articleTitle = (UILabel *)[cell viewWithTag:101];
    articleTitle.text = [self.issue articleAtIndex:indexPath.row].title;
    
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
    
    NSMutableAttributedString *articleTeaserAttributedString = [[NSMutableAttributedString alloc] initWithData:[teaserHTML dataUsingEncoding:NSUTF8StringEncoding]
                                                                                         options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType}
                                                                              documentAttributes:nil
                                                                                           error:nil];
    // TODO: isn't listening to stylesheet.
    
//    // TODO: These override the bolds. :-(
//    [articleTeaserAttributedString addAttributes:@{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]}
//                                           range:NSMakeRange(0, [articleTeaserAttributedString length])];
    
//    [articleTeaserAttributedString enumerateAttribute:NSFontAttributeName
//                            inRange:NSMakeRange(0, [articleTeaserAttributedString length])
//                            options:0
//                         usingBlock:^(id value,
//                                      NSRange range,
//                                      BOOL * stop)
//     {
//         UIFontDescriptor *fd = [[value fontDescriptor] fontDescriptorWithFamily:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline].familyName];
//         UIFont *font = [UIFont fontWithDescriptor:fd size:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline].pointSize];
//         if (font != nil) {
//             [articleTeaserAttributedString removeAttribute:NSFontAttributeName
//                                    range:range];
//             [articleTeaserAttributedString addAttribute:NSFontAttributeName
//                                 value:font
//                                 range:range];
//         }
//     }];
    
    articleTeaser.attributedText = articleTeaserAttributedString;
}

- (void)setupCell: (UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

    UIImageView *articleImageView = (UIImageView *)[cell viewWithTag:100];
    NIAUArticle *article = [self.issue articleAtIndex:indexPath.row];
    CGSize thumbSize = CGSizeMake(57,43);
    if (self.tableView.dragging == NO && self.tableView.decelerating == NO) {
        if (articleImageView.image == [UIImage imageNamed:@"default_article_image_table_view.png"]) {
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
        [self.imageView setImage:img];
    }];
    
//    self.labelTitle.text = self.issue.title;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMMM yyyy"];
    self.labelNumberAndDate.text = [NSString stringWithFormat: @"%@ - %@", self.issue.name, [dateFormatter stringFromDate:self.issue.publication]];
    self.labelEditor.text = [NSString stringWithFormat:@"Edited by:\n%@", self.issue.editorsName];
    self.editorsLetterTextView.text = self.issue.editorsLetter;
    
//    [self.editorImageView setImage:[UIImage imageNamed:@"default_editors_photo"]];
    // Load the real editor's image
//    [self.issue getEditorsImageWithCompletionBlock:^(UIImage *img) {
//        [self.editorImageView setImage:img];
//    }];
//    [self applyRoundMask:self.editorImageView];
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
    
    NSArray *itemsToShare = @[[NSString stringWithFormat:@"I'm reading the New Internationalist magazine - %@",self.issue.title], self.imageView.image, self.issue.getWebURL];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
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
    [self updateScrollViewContentHeight];
}

@end
