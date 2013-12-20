//
//  NIAUArticleViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUArticleViewController.h"
#import "NIAUImageZoomViewController.h"
#import "Reachability.h"
#import "NIAUArticleCategoryCell.h"

NSString *kCategoryCellID = @"categoryCellID";

@interface NIAUArticleViewController ()

@end

@implementation NIAUArticleViewController

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
    
    // Setting object to nil because self.article changes when pulling to refresh
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(articleBodyLoaded:) name:ArticleDidUpdateNotification object:nil];
    
    // Setting object to nil because self.article changes when pulling to refresh
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(articleBodyDidntLoad:) name:ArticleFailedUpdateNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(articlesLoaded:) name:ArticlesDidUpdateNotification object:[self.article issue]];
    
    // Add observer for the user changing the text size
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    // Doing the requestBody call in viewWillAppear so that it loads after logging in to Rails too.
//    [self.article requestBody];
    
    // Only need to call this when the article body is loaded
//    [self setupData];
    
    // In the meantime, blank the placeholder text.
    self.titleLabel.text = @"";
    self.teaserLabel.text = @"";
    
    [self updateScrollViewContentHeight];
    
    // Setup pull-to-refresh for the UIWebView
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:refreshControl];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.article requestBody];
//    NSLog(@"View will appear!!!");
}

- (void)articleBodyLoaded:(NSNotification *)notification
{
    [self setupData];
}

- (void)articleBodyDidntLoad:(NSNotification *)notification
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus netStatus = [reachability currentReachabilityStatus];
    
    if (netStatus == NotReachable) {
        // Ask them to turn on wifi or get internet access.
        [[[UIAlertView alloc] initWithTitle:@"Internet access?" message:@"It doesn't seem like you have internet access, turn it on to subscribe or download this article." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    } else if (![self.article isRailsServerReachable]) {
        // Pop an alert saying sorry, it's our problem
        [[[UIAlertView alloc] initWithTitle:@"Uh oh!" message:@"We're really really sorry! Looks like our server is unavailable. :-(" delegate:self cancelButtonTitle:@"Try again later." otherButtonTitles:nil] show];
    } else {
        // Pop up an alert asking the user to subscribe!
        [[[UIAlertView alloc] initWithTitle:@"Subscribe?" message:@"It doesn't look like you're a subscriber or if you are, perhaps you haven't logged in yet. What would you like to do?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Subscribe", @"Log-in", nil] show];
    }
}

- (void)articlesLoaded:(NSNotification *)notification
{
    // Switch to the new article object
    self.article = [[self.article issue] articleWithRailsID:self.article.railsID];
    [self.article requestBody];
}

- (void)preferredContentSizeChanged:(NSNotification *)aNotification
{
    NSLog(@"Notification received for text change!");
    
    // adjust the layout of the cells
    self.titleLabel.font = [NIAUArticleViewController headlineFontWithScale:2];
    
    // TODO: work out how to update the webView & textView.attributedText font sizes.
//    self.teaserLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    
    [self.view setNeedsLayout];
}

+ (UIFont *)headlineFontWithScale: (float)scale
{
    UIFont *currentDynamicFontSize = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    if (IS_IPAD()) {
        return [currentDynamicFontSize fontWithSize:currentDynamicFontSize.pointSize*scale];
    } else {
        return [currentDynamicFontSize fontWithSize:currentDynamicFontSize.pointSize*scale*.8];
    }
}

- (void)setupData
{
    // Tried to use system font.. seems to be different for webview
    // #define kbodyWebViewFont @"-apple-system-body"
    
    //Get the real article images.
    [self.article getFeaturedImageWithCompletionBlock:^(UIImage *img) {
        if (img) {
            [self.featuredImage setAlpha:0.0];
            [self.featuredImage setImage:img];
            [UIView animateWithDuration:0.3 animations:^{
                [self.featuredImage setAlpha:1.0];
            }];
        } else {
            [UIView animateWithDuration:0.3 animations:^{
                // Update the height constraint of self.featuredImage to make it skinny.
                [self.featuredImage.constraints[0] setConstant:50.0];
            }];
        }
    }];
    NSDictionary *firstCategory = self.article.categories.firstObject;
    id categoryColour = WITH_DEFAULT([firstCategory objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
    self.featuredImage.backgroundColor = UIColorFromRGB([categoryColour integerValue]);

    self.titleLabel.text = WITH_DEFAULT(self.article.title,IF_DEBUG(@"!!!NOTITLE!!!",@""));
    self.titleLabel.font = [NIAUArticleViewController headlineFontWithScale:2];
//    self.teaserLabel.text = WITH_DEFAULT(self.article.teaser,IF_DEBUG(@"!!!NOTEASER!!!",@""));
    self.authorLabel.text = WITH_DEFAULT(self.article.author,IF_DEBUG(@"!!!NOAUTHOR!!!",@""));
    
    // Load CSS from the filesystem
    NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"article-body" withExtension:@"css"];
    
    // Load the article teaser into the attributedText
    NSString *teaserHTML = [NSString stringWithFormat:@"<html> \n"
                            "<head> \n"
                            "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\">"
                            "</head> \n"
                            "<body><div class='article-teaser'>%@</div></body> \n"
                            "</html>", cssURL, WITH_DEFAULT(self.article.teaser,IF_DEBUG(@"!!!NOTEASER!!!",@""))];
    
    if ([self.article.teaser isEqualToString:@""]) {
        NSLog(@"Article doesn't have a teaser");
        self.teaserLabel.text = nil;
    } else {
        self.teaserLabel.attributedText = [[NSAttributedString alloc] initWithData:[teaserHTML dataUsingEncoding:NSUTF8StringEncoding]
                                                                           options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                                     NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
                                                                documentAttributes:nil
                                                                             error:nil];
    }
    
    // Load the article into the webview
    
    NSString *bodyFromDisk = [self.article attemptToGetExpandedBodyFromDisk];
    
    NSString *bodyWebViewHTML = [NSString stringWithFormat:@"<html> \n"
                                   "<head> \n"
                                   "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\">"
                                   "</head> \n"
                                   "<body>%@</body> \n"
                                   "</html>", cssURL, WITH_DEFAULT(bodyFromDisk, @"")];
    [self.bodyWebView loadHTMLString:bodyWebViewHTML baseURL:nil];
    
    // Prevent webview from scrolling
    if ([self.bodyWebView respondsToSelector:@selector(scrollView)]) {
        self.bodyWebView.scrollView.scrollEnabled = NO;
    }
}

- (void)updateScrollViewContentHeight
{
    CGRect contentRect = CGRectZero;
    for (UIView *view in self.scrollView.subviews) {
        contentRect = CGRectUnion(contentRect, view.frame);
    }
    self.scrollView.contentSize = contentRect.size;
}

- (void)updateWebViewHeight
{
    // Set the webview size
    CGSize size = [self.bodyWebView sizeThatFits: CGSizeMake(320., 1.)];
    CGRect frame = self.bodyWebView.frame;
    frame.size.height = size.height;
    self.bodyWebView.frame = frame;
    
    // Update the constraints.
    CGFloat contentHeight = self.bodyWebView.frame.size.height + 20;
    
    self.bodyWebViewHeightConstraint.constant = contentHeight;
    [self.view needsUpdateConstraints];
    NSLog(@"Updated webview height");
}

#pragma mark -
#pragma mark UICollectionView delegate

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section;
{
    return self.article.categories.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    NIAUArticleCategoryCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kCategoryCellID forIndexPath:indexPath];
    
    // make the cell's title the actual NSIndexPath value
    // cell.label.text = [NSString stringWithFormat:@"{%ld,%ld}", (long)indexPath.row, (long)indexPath.section];
    
    NSDictionary *category = self.article.categories[indexPath.row];
    
    // Remove the slash and only take the last word
    NSArray *categoryParts = @[];
    NSString *textString = [category objectForKey:@"name"];
    categoryParts = [textString componentsSeparatedByString:@"/"];
    
    cell.categoryLabel.text = [[categoryParts[[categoryParts count]-2] capitalizedString] stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    
    // Round the cell corners
    cell.layer.masksToBounds = YES;
    cell.layer.cornerRadius = 3.;
    
    // Adjust the size of the cell to fit the label + 10
    CGSize labelSize = [cell.categoryLabel intrinsicContentSize];
    [cell setFrame:CGRectMake(cell.frame.origin.x, cell.frame.origin.y, labelSize.width + 10., 20.)];
    
//    // Set the background colour to the category colour
//    id categoryColour = WITH_DEFAULT([category objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
//    cell.backgroundColor = UIColorFromRGB([categoryColour integerValue]);
    
    return cell;
}

//- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
//{
//    return UIEdgeInsetsMake(0, 0, 0, 10);
//}

#pragma mark -
#pragma mark AlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0:
            // Cancel pressed
            [self.navigationController popViewControllerAnimated:YES];
            break;
        case 1:
            // Segue to subscription
            [self performSegueWithIdentifier:@"alertToSubscribe" sender:nil];
            break;
        case 2:
            // Segue to log-in
            [self performSegueWithIdentifier:@"alertToLogin" sender:nil];
            break;
        default:
            break;
    }
}

#pragma mark -
#pragma mark Refresh delegate

-(void)handleRefresh:(UIRefreshControl *)refresh {
    [self.article clearCache];
    [[self.article issue] forceDownloadArticles];
    [refresh endRefreshing];
}

#pragma mark -
#pragma mark WebView delegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self.webViewLoadingIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.webViewLoadingIndicator stopAnimating];
    [self ensureScrollsToTop: webView];
    [self updateWebViewHeight];
}

- (void) ensureScrollsToTop: (UIView *) ensureView {
    ((UIScrollView *)[[self.bodyWebView subviews] objectAtIndex:0]).scrollsToTop = NO;
}

#pragma mark -
#pragma mark Social sharing

- (IBAction)shareActionTapped:(id)sender
{
    NSMutableArray *itemsToShare = [[NSMutableArray alloc] initWithArray:@[[NSString stringWithFormat:@"I'm reading '%@' from New Internationalist magazine.",self.article.title], self.article.getWebURL]];
    
    // Only add the featured image if it exists
    if (self.featuredImage.image != nil) {
        [itemsToShare addObject:self.featuredImage.image];
    }
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [activityController setValue:[NSString stringWithFormat:@"%@", self.article.title] forKey:@"subject"];
    [self presentViewController:activityController animated:YES completion:nil];
}

#pragma mark -
#pragma mark Responding to gestures

- (IBAction)handleFeaturedImageSingleTap:(UITapGestureRecognizer *)recognizer
{
    // Handle image being tapped
    
    // TODO: Fix this test, it's a little brittle...
    if (recognizer.view.frame.size.height > 130) {
        [self performSegueWithIdentifier:@"showImageZoom" sender:recognizer.view];
    } else {
        // Doesn't have a featured image, so segue to the category tapped
        [self performSegueWithIdentifier:@"articleToCategory" sender:self];
    }
    
}

- (IBAction)handleSecondTestImageSingleTap:(UITapGestureRecognizer *)recognizer
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
#pragma mark Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showImageZoom"]) {
        // TODO: Load the large version of the image to be zoomed.
        NIAUImageZoomViewController *imageZoomViewController = [segue destinationViewController];
        
        if ([sender isKindOfClass:[UIImageView class]]) {
            UIImageView *imageTapped = (UIImageView *)sender;
            imageZoomViewController.imageToLoad = imageTapped.image;
        } else {
            imageZoomViewController.imageToLoad = [UIImage imageNamed:@"default_article_image.png"];
        }
    } else if ([[segue identifier] isEqualToString:@"articleToCategory"]) {
        NIAUCategoryViewController *categoryViewController = [segue destinationViewController];
        
        // TODO: when categories are listed on the article page, choose the category tapped.
        categoryViewController.category = [[self.article.categories firstObject] objectForKey:@"name"];
        
    } else if ([[segue identifier] isEqualToString:@"showArticlesInCategory"]) {
        NSIndexPath *selectedIndexPath = [[self.categoryCollectionView indexPathsForSelectedItems] objectAtIndex:0];
        
        NIAUCategoryViewController *categoryViewController = [segue destinationViewController];
        categoryViewController.category = [self.article.categories[selectedIndexPath.row] objectForKey:@"name"];
    }
}

#pragma mark -
#pragma mark Rotation handling

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    // TODO: Fix the scrollview height for landscape.
    [self updateWebViewHeight];
    [self updateScrollViewContentHeight];
}

@end
