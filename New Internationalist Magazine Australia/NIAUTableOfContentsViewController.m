//
//  NIAUTableOfContentsViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 26/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUTableOfContentsViewController.h"
#import "NIAUImageZoomViewController.h"
#import "NSAttributedString+HTML.h"

@interface NIAUTableOfContentsViewController ()

@end

@implementation NIAUTableOfContentsViewController

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:ArticlesDidUpdateNotification object:self.issue];
    
    [self.issue requestArticles];
    
    // Add the data for the view
    [self setupData];
    
    // Set the editorsLetterTextView height to its content.
    [self updateEditorsLetterTextViewHeightToContent];
    
//    // Set the exclusion path around the editors letter
//    [self updateEditorsLetterTextViewExclusionPath];
    
    // Set the scrollView content height to the editorsLetterTextView.
    [self updateScrollViewContentHeight];
    
    // Enable tapping the top bar to scroll to top for the scrollview by disabling it on the tableview
    [self.tableView setScrollsToTop:NO];
}

-(void)publisherReady:(NSNotification *)not
{
    [self showArticles];
}

-(void)showArticles
{
    [self.tableView reloadData];
    [self updateEditorsLetterTextViewHeightToContent];
    [self adjustHeightOfTableview];
    [self updateScrollViewContentHeight];
}

- (void)adjustHeightOfTableview
{
    CGFloat height = self.tableView.contentSize.height;
    
    // now set the height constraint accordingly
    
    [UIView animateWithDuration:.25 animations:^{
        self.tableViewHeightConstraint.constant = height;
        [self.view needsUpdateConstraints];
    }];
}

- (void)adjustWidthOfMagazineCover
{
    CGFloat width = self.view.frame.size.height / 2.;
    
    // now set the width constraint accordingly
    
    [UIView animateWithDuration:.25 animations:^{
        self.magazineCoverWidthConstraint.constant = width;
        [self.view needsUpdateConstraints];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.issue numberOfArticles];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"articleCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self tableView:tableView cellForHeightForRowAtIndexPath:indexPath];
    [self setupCell:cell atIndexPath:indexPath];
    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self tableView:tableView cellForHeightForRowAtIndexPath:indexPath];
    
    NSLog(@"cell.textLabel.text=%@",cell.textLabel.text);
    
    // set the frame to be the same size as the tableView (only really to get the width)
    cell.frame = tableView.frame;
    NSLog(@"cell.frame.width=%f",cell.frame.size.width);
    // temporarily store the contents of the textlabel
    NSString *tmp = cell.textLabel.text;
    // and set it to a really wide string
    cell.textLabel.text = [@"" stringByPaddingToLength:500 withString:@" X" startingAtIndex:0];
    // then update the layout
    [cell layoutIfNeeded];
    // pull out the size of the textLabel to get it's maximum possible size
    CGSize 	maxSize = cell.textLabel.frame.size;
    
    //WTF: first time through this gets random smaller sizes...
    
//    NSLog(@"maxSize.width=%f",maxSize.width);
    
    // replace the original text
    cell.textLabel.text = tmp;
    
    // inspired by http://doing-it-wrong.mikeweller.com/2012/07/youre-doing-it-wrong-2-sizing-labels.html
    
    CGFloat textHeight = [cell.textLabel sizeThatFits:maxSize].height;
    
    CGFloat detailTextHeight =  [cell.detailTextLabel sizeThatFits:maxSize].height;
    
//    NSLog(@"textHeight=%f",textHeight);
//    NSLog(@"detailTextHeight=%f",detailTextHeight);
    
    // TODO: work out how to set the padding to the standard value
    
    return textHeight + detailTextHeight + 20.;
}

- (void)setupCellForHeight: (UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

    cell.imageView.image = [UIImage imageNamed:@"default_article_image_table_view.png"];
    // TODO: possibly replace the imageview with our own,
    // see http://stackoverflow.com/questions/3182649/ios-sdk-uiviewcontentmodescaleaspectfit-vs-uiviewcontentmodescaleaspectfill
    
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.textLabel.text = [self.issue articleAtIndex:indexPath.row].title;
//    TODO: For Pix to fix - attributedText for article teasers
//    cell.detailTextLabel.attributedText = [[NSAttributedString alloc] initWithHTMLData:[[self.issue articleAtIndex:indexPath.row].teaser dataUsingEncoding:NSUTF8StringEncoding] baseURL:nil documentAttributes:nil];
    id teaser = [self.issue articleAtIndex:indexPath.row].teaser;
    cell.detailTextLabel.text =  (teaser==[NSNull null]) ? @"" : teaser;
}

- (void)setupCell: (UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    [self setupCellForHeight:cell atIndexPath:indexPath];
//    [[self.issue articleAtIndex:indexPath.row] getFeaturedImageWithSize:CGSizeMake(57,43) andCompletionBlock:^(UIImage *img) {
//        NSLog(@"completion block got image with width %f",[img size].width);
//        [cell.imageView setImage:img];
//        //[cell.imageView setNeedsLayout];
//        // TODO: do we need to force a redraw?
//    }];
}


#pragma mark -
#pragma mark Setup Data

- (void)setupData
{
    // Set the cover from the issue cover tapped
    [self.issue getCoverWithCompletionBlock:^(UIImage *img) {
        [self.imageView setImage:img];
        [self.imageView setNeedsLayout];
    }];
    
    self.labelTitle.text = self.issue.title;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMMM yyyy"];
    self.labelNumberAndDate.text = [NSString stringWithFormat: @"%@ - %@", self.issue.name, [dateFormatter stringFromDate:self.issue.publication]];
    self.labelEditor.text = [NSString stringWithFormat:@"Editor's letter by %@", self.issue.editorsName];
    self.editorsLetterTextView.text = self.issue.editorsLetter;
    
    [self.editorImageView setImage:[UIImage imageNamed:@"default_editors_photo"]];
    // Load the real editor's image
    [self.issue getEditorsImageWithCompletionBlock:^(UIImage *img) {
        [self.editorImageView setImage:img];
        [self.editorImageView setNeedsLayout];
    }];
    [self applyRoundMask:self.editorImageView];
}

- (void)applyRoundMask:(UIImageView *)imageView
{
    // Draw a round mask for images.. i.e. the editor's photo
    imageView.layer.masksToBounds = YES;
    imageView.layer.cornerRadius = self.editorImageView.bounds.size.width / 2.;
}

- (void)updateEditorsLetterTextViewExclusionPath
{
    // Wrap the text around the editor's photo
    
    // TODO: Work out how to only exclude words not characters. For now I'll just use a square exclusionPath.
    // self.editorsLetterTextView.textContainer.exclusionPaths = @[[UIBezierPath bezierPathWithRoundedRect:editorImageViewRect cornerRadius:self.editorImageView.layer.cornerRadius]];
    
    self.editorsLetterTextView.textContainer.exclusionPaths = nil;
    CGRect editorImageViewRect = [self.editorsLetterTextView convertRect:self.editorImageView.frame fromView:self.view];
    self.editorsLetterTextView.textContainer.exclusionPaths = @[[UIBezierPath bezierPathWithRect:editorImageViewRect]];
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
    
    [self adjustWidthOfMagazineCover];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
//    [self updateEditorsLetterTextViewExclusionPath];
    [self updateEditorsLetterTextViewHeightToContent];
    [self adjustHeightOfTableview];
    [self updateScrollViewContentHeight];
}

@end
