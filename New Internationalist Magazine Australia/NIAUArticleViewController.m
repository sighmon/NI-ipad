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
#import "NIAUTableOfContentsViewController.h"

NSString *kCategoryCellID = @"categoryCellID";
float cellPadding = 10.;
float titleHeadingFontScale = 2.5;

NSString *ArticleDidRefreshNotification = @"ArticleDidRefresh";

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageFinishedDownloadingToCache:) name:ImageDidSaveToCacheNotification object:nil];
    
    // Add observer for the user changing the text size
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    // Add observer for the article refresh
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(articleBodyLoaded:) name:ArticleDidRefreshNotification object:nil];

    // Doing the requestBody call in viewWillAppear so that it loads after logging in to Rails too.
//    [self.article requestBody];
    
    // Only need to call this when the article body is loaded
//    [self setupData];
    
    // In the meantime, blank the placeholder text.
    self.titleLabel.text = @"";
    self.teaserLabel.text = @"";
    [self.dateButton setTitle:@"" forState:UIControlStateNormal];
    
    // Set the back button title for the article (first 14 characters, plus 3 dots)
    int titleLength = (int)[self.article.title length];
    if (titleLength > 10) {
        titleLength = 10;
    }
    [[self.navigationItem backBarButtonItem] setTitle:[NSString stringWithFormat:@"%@...", [self.article.title substringToIndex:titleLength]]];
    
    [self updateScrollViewContentHeight];
    
    [self updateCategoryCollectionViewHeight];
    self.categoryCollectionView.scrollsToTop = NO;
    
    // Setup pull-to-refresh for the UIWebView
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:refreshControl];
    
    // Set height constraint to 0.0 incase there isn't a featured image
    [self.featuredImage.constraints[0] setConstant:0.0];
    
    // Setup two finger swipe to pop to root view
    UISwipeGestureRecognizer *twoFingerSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerSwipe:)];
    twoFingerSwipe.numberOfTouchesRequired = 2;
    
    [self.view addGestureRecognizer:twoFingerSwipe];

    // Check if user is okay with sending analytics
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if ([standardUserDefaults boolForKey:@"googleAnalytics"] == 1) {
        [self sendGoogleAnalyticsStats];
    }
    
    // Add article to recently read list
    [self addArticleToRecentlyReadArticles];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Set the margin for the title, teaser, date, and categories to match the CSS
    [self updateTitleViewWidth];

    if (self.isArticleBodyLoaded) {
        [self.bodyWebView scalesPageToFit];
        [self.bodyWebView autoresizesSubviews];
        NSString *articleBody = [self.bodyWebView stringByEvaluatingJavaScriptFromString:@"document.documentElement.outerHTML"];
        BOOL hasBody = [articleBody containsString:@"<div class=\"article-body\">"];
        if (!hasBody) {
            // Article needs reloading - user may have just logged in
            [self.article requestBody];
        }
    } else {
        [self.article requestBody];
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
    NSString *analyticsString = [NSString stringWithFormat:@"%@ (%@)", self.article.title, self.article.issue.name];
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:analyticsString];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createScreenView] build]];
    
    // Post to Firebase
    [FIRAnalytics logEventWithName:@"openScreen"
                        parameters:@{
                                     @"name": analyticsString,
                                     @"screenName": analyticsString
                                     }];
}

- (void)addArticleToRecentlyReadArticles
{
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.au.com.newint.New-Internationalist-Magazine-Australia"];
    NSMutableArray *recentlyReadArticles = [[NSMutableArray alloc] initWithArray:[userDefaults objectForKey:@"recentlyReadArticles"]];

    NSMutableArray *reversedRecentlyReadArticles = [[NSMutableArray alloc] initWithArray:[[recentlyReadArticles reverseObjectEnumerator] allObjects]];

    // Create a dictionary with the title, railsID, issueRailsID and dateRead.
    NSMutableDictionary *articleToAdd = [[NSMutableDictionary alloc] init];
    [articleToAdd setObject:self.article.title forKey:@"title"];
    [articleToAdd setObject:self.article.railsID forKey:@"railsID"];
    [articleToAdd setObject:self.article.issue.railsID forKey:@"issueRailsID"];
    [articleToAdd setObject:[NSDate date] forKey:@"dateRead"];

    // Check to see if it's in the list already
    NSArray *filtered = [reversedRecentlyReadArticles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title = %@", self.article.title]];
    if ([filtered count] > 0) {
        // Remove the duplicate(s)
        for (id article in filtered) {
            DebugLog(@"Removing article: %@", article);
            [reversedRecentlyReadArticles removeObject:article];
        }
    }
    // Add the article & sync
    DebugLog(@"Adding article: %@", articleToAdd);
    [reversedRecentlyReadArticles addObject:articleToAdd];

    // If the list is bigger than 20, remove the first.
    if (reversedRecentlyReadArticles.count > 20) {
        [reversedRecentlyReadArticles removeObjectAtIndex:0];
    }

    // Reverse the order once again.
    [recentlyReadArticles removeAllObjects];
    [recentlyReadArticles addObjectsFromArray:[[reversedRecentlyReadArticles reverseObjectEnumerator] allObjects]];
    DebugLog(@"Recently read articles after addition: %@", recentlyReadArticles);

    // Sync the articles back again.
    [userDefaults setObject:recentlyReadArticles forKey:@"recentlyReadArticles"];
    [userDefaults synchronize];
}

- (void)articleBodyLoaded:(NSNotification *)notification
{
    self.isArticleBodyLoaded = TRUE;
    [self setupData];
}

- (void)articleBodyDidntLoad:(NSNotification *)notification
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus netStatus = [reachability currentReachabilityStatus];
    
    if (netStatus == NotReachable) {
        // Ask them to turn on wifi or get internet access.
        self.alertView = [[UIAlertView alloc] initWithTitle:@"Internet access?" message:@"It doesn't seem like you have internet access, turn it on to subscribe or download this article." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [self.alertView show];
    } else if (![self.article isRailsServerReachable]) {
        // Pop an alert saying sorry, it's our problem
        self.alertView = [[UIAlertView alloc] initWithTitle:@"Uh oh!" message:@"We're really really sorry! Looks like our server is unavailable. :-(" delegate:self cancelButtonTitle:@"Try again later." otherButtonTitles:nil];
        [self.alertView show];
    } else {
        // Pop up an alert asking the user to subscribe!
        self.alertView = [[UIAlertView alloc] initWithTitle:@"Subscribe?" message:@"It doesn't look like you're a subscriber or if you are, perhaps you haven't logged in yet. What would you like to do?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Subscribe", @"Log-in", nil];
        [self.alertView show];
    }
}

- (void)articlesLoaded:(NSNotification *)notification
{
    // Switch to the new article object
    self.article = [[self.article issue] articleWithRailsID:self.article.railsID];
    [self.article requestBody];
}

- (void)imageFinishedDownloadingToCache:(NSNotification *)notification
{
    // Find image in webview by ID and then replace with real URL
    NSArray *imageInformation = [notification.userInfo objectForKey:@"image"];
    DebugLog(@"Received image cache notification from ID:%@", imageInformation[0]);
    NSString *javascriptString = [NSString stringWithFormat:@"var img = document.getElementById('image%@'); img.src = '%@'; img.parentElement.href = '%@'", imageInformation[0], imageInformation[1], imageInformation[1]];
    
    // TODO: Work out why this is causing memory warnings. Possibly 10mb javascript limit?
    [self.bodyWebView stringByEvaluatingJavaScriptFromString:javascriptString];
    
    // Update view size
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateWebViewHeight];
        [self updateScrollViewContentHeight];
    });
}

#pragma mark - Dynamic Text

- (void)preferredContentSizeChanged:(NSNotification *)notification
{
    NSLog(@"Notification received for text change!");
    
    // adjust the layout of the title
    self.titleLabel.font = [NIAUHelper scaleFont:UIFontTextStyleHeadline withScale:titleHeadingFontScale andiPadSizeCompensation:TRUE];
    
    // NIAUHelper fontSizePercentage is set by the current user font scaling size
    // Then we call setupData to reload everything.
    [self setupData];
}

#pragma mark - Setup

- (void)setupData
{
    // Tried to use system font.. seems to be different for webview
    // #define kbodyWebViewFont @"-apple-system-body"
    
    // Get the featured image.
    [self.article getFeaturedImageWithCompletionBlock:^(UIImage *img) {
        if (img) {
            [self.featuredImage setAlpha:0.0];
            [self.featuredImage setImage:img];
            // Image ratio of raw image from Rails
            float featuredImageRatio = 1890/800.;
            float featuredImageHeight = self.featuredImage.frame.size.width/featuredImageRatio;
            if (IS_IPAD()) {
                [self.featuredImage.constraints[0] setConstant:featuredImageHeight];
            } else {
                [self.featuredImage.constraints[0] setConstant:featuredImageHeight];
            }
            [UIView animateWithDuration:0.3 animations:^{
                [self.featuredImage setAlpha:1.0];
            }];
        } else {
            [UIView animateWithDuration:0.3 animations:^{
                // Update the height constraint of self.featuredImage to make it skinny.
                [self.featuredImage.constraints[0] setConstant:0.0];
            }];
        }
    }];
    
    NSDictionary *firstCategory = self.article.categories.firstObject;
    id categoryColour = WITH_DEFAULT([firstCategory objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
    self.featuredImage.backgroundColor = UIColorFromRGB([categoryColour integerValue]);

    self.titleLabel.text = WITH_DEFAULT(self.article.title,IF_DEBUG(@"!!!NOTITLE!!!",@""));
    self.titleLabel.font = [NIAUHelper scaleFont:UIFontTextStyleHeadline withScale:titleHeadingFontScale andiPadSizeCompensation:TRUE];
//    self.teaserLabel.text = WITH_DEFAULT(self.article.teaser,IF_DEBUG(@"!!!NOTEASER!!!",@""));
    self.authorLabel.text = WITH_DEFAULT(self.article.author,IF_DEBUG(@"!!!NOAUTHOR!!!",@""));
    
    // Load CSS from the filesystem
    NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"article-body" withExtension:@"css"];
    NSURL *bootstrapCssURL = [[NSBundle mainBundle] URLForResource:@"bootstrap" withExtension:@"css"];
    
    // Set the font size percentage from Dynamic Type
    NSString *fontSizePercentage = [NIAUHelper fontSizePercentage];
    
    // Load the article teaser into the attributedText
    NSString *teaserHTML = [NSString stringWithFormat:@"<html> \n"
                            "<head> \n"
                            "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                            "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                            "</head> \n"
                            "<body style='font-size: %@'><div class='article-teaser'>%@</div></body> \n"
                            "</html>", bootstrapCssURL, cssURL, fontSizePercentage, WITH_DEFAULT(self.article.teaser,IF_DEBUG(@"!!!NOTEASER!!!",@""))];
    
    if (self.article.teaser == (id)[NSNull null] || [self.article.teaser isEqualToString:@""]) {
        DebugLog(@"Article doesn't have a teaser");
        self.teaserLabel.text = nil;
    } else {
        self.teaserLabel.attributedText = [[NSAttributedString alloc] initWithData:[teaserHTML dataUsingEncoding:NSUTF8StringEncoding]
                                                                           options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                                     NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
                                                                documentAttributes:nil
                                                                             error:nil];
    }
    
    // Autolayout magic to set it to the right width
    self.teaserLabel.preferredMaxLayoutWidth = self.scrollView.frame.size.width;
    
    // Format the date
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    [dateFormatter setDateFormat:@"MMMM yyyy"];
    
    [self.dateButton setTitle:[NSString stringWithFormat: @"%@", [dateFormatter stringFromDate:WITH_DEFAULT(self.article.publication,self.article.issue.publication)]] forState:UIControlStateNormal];
    
    [self.dateButton.titleLabel setFont:[NIAUHelper scaleFont:UIFontTextStyleBody withScale:1 andiPadSizeCompensation:FALSE]];
    
    // Load the article into the webview
    
    NSString *bodyFromDisk = [self.article attemptToGetExpandedBodyFromDisk];
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    NSString *bodyWebViewHTML = [NSString stringWithFormat:@"<html> \n"
                                   "<head> \n"
                                   "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                                   "<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"> \n"
                                   "</head> \n"
                                   "<body style='font-size: %@'>%@</body> \n"
                                   "</html>", bootstrapCssURL, cssURL, fontSizePercentage, WITH_DEFAULT(bodyFromDisk, @"")];
    [self.bodyWebView loadHTMLString:bodyWebViewHTML baseURL:baseURL];
    
    // Prevent webview from scrolling
    if ([self.bodyWebView respondsToSelector:@selector(scrollView)]) {
        self.bodyWebView.scrollView.scrollEnabled = NO;
    }
    
    // If help is enabled, show help alert
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"showHelp"] == 1) {
        [NIAUHelper showHelpAlertWithMessage:@"You can share this article with friends, even if they don't have the app? To do that press the 'share' button on the top right of this screen." andDelegate:self];
    }
    
    // TODO: Build related articles
    
    // TODO: insert next and previous article buttons.
}

- (void)updateScrollViewContentHeight
{
    CGRect contentRect = CGRectZero;
    for (UIView *view in self.scrollView.subviews) {
        contentRect = CGRectUnion(contentRect, view.frame);
    }
    self.scrollView.contentSize = contentRect.size;
    [self.scrollView setNeedsUpdateConstraints];
    [self.scrollView setNeedsLayout];
    DebugLog(@"Updated scrollview height to: %f", self.scrollView.contentSize.height);
}

- (void)updateWebViewHeight
{
    // Set the webview size
    CGSize size = [self.bodyWebView sizeThatFits: CGSizeMake(self.view.frame.size.width, 1.)];
    CGRect frame = self.bodyWebView.frame;
    frame.size.height = size.height;
    self.bodyWebView.frame = frame;
    
    // Update the constraints.
    CGFloat contentHeight = self.bodyWebView.frame.size.height + 20 + (self.article.images.count * 1000);
    
    self.bodyWebViewHeightConstraint.constant = contentHeight;
    [self.bodyWebView setNeedsUpdateConstraints];
    [self.bodyWebView setNeedsLayout];
//    DebugLog(@"Current width of self.view: %f", self.view.frame.size.width);
    DebugLog(@"Updated webview height to: %f", self.bodyWebView.frame.size.height);
}

- (void)updateCategoryCollectionViewHeight
{
    [self.categoryCollectionViewHeightConstraint setConstant:[self.categoryCollectionView.collectionViewLayout collectionViewContentSize].height];
}

- (void)updateTitleViewWidth
{
    // Set the margin for the title, teaser, date, and categories to match the CSS
    if (self.view.frame.size.width >= 569) {
        // css margin is 15% of screen width
        float cssMargin = 15;
        float screenWidth = self.view.frame.size.width;
        float titleViewWidth = screenWidth * ((100 - (cssMargin * 2)) / 100);
        self.titleViewWidthConstraint.constant = titleViewWidth;
    }
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
    // Handle no slashes
    if ([categoryParts count] > 1) {
        cell.categoryLabel.text = [[categoryParts[[categoryParts count]-2] capitalizedString] stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    } else {
        // No slashes, new Drupal category type.
        cell.categoryLabel.text = [categoryParts[0] capitalizedString];
    }
    
    // Round the cell corners
    cell.layer.masksToBounds = YES;
    cell.layer.cornerRadius = 3.;
    
    // Adjust the size of the cell to fit the label + cellPadding
//    CGSize labelSize = [cell.categoryLabel intrinsicContentSize];
//    [cell setFrame:CGRectMake(cell.frame.origin.x, cell.frame.origin.y, labelSize.width + cellPadding, 20.)];
    
//    // Set the background colour to the category colour
//    id categoryColour = WITH_DEFAULT([category objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
//    cell.backgroundColor = UIColorFromRGB([categoryColour integerValue]);
    
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // TOFIX: Ugly hack creates UILabel to calculate width of cell, pix to fix.
    
    UILabel *categoryLabel = [[UILabel alloc] init];
    categoryLabel.font = [UIFont boldSystemFontOfSize:10];
    // Check if the article has any categories
    if ([self.article.categories count] > 0) {
        NSDictionary *category = self.article.categories[indexPath.row];
        // Remove the slash and only take the last word
        NSArray *categoryParts = @[];
        NSString *textString = [category objectForKey:@"name"];
        categoryParts = [textString componentsSeparatedByString:@"/"];
        // Handle no slashes
        if ([categoryParts count] > 1) {
            categoryLabel.text = [[categoryParts[[categoryParts count]-2] capitalizedString] stringByReplacingOccurrencesOfString:@"-" withString:@" "];
        } else {
            // No slashes, new Drupal category type.
            categoryLabel.text = [categoryParts[0] capitalizedString];
        }
    }
    
    return CGSizeMake([categoryLabel intrinsicContentSize].width + cellPadding, 20.);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 10.;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *category = self.article.categories[indexPath.row];
    id categoryColour = WITH_DEFAULT([category objectForKey:@"colour"],[NSNumber numberWithInt:0xFFFFFF]);
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    cell.backgroundColor = UIColorFromRGB([categoryColour integerValue]);
}

#pragma mark -
#pragma mark AlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Subscribe?"] || [alertView.title isEqualToString:@"Internet access?"]) {
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

#pragma mark -
#pragma mark Refresh delegate

-(void)handleRefresh:(UIRefreshControl *)refresh {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.article clearCache];
        NIAUIssue *issue = [self.article issue];
        [issue forceDownloadArticles];
        [issue getCategoriesSortedStartingAt:@"net"];
        [issue getArticlesSortedStartingAt:@"net"];
        dispatch_async(dispatch_get_main_queue(), ^{
            // Send notification for TableViewController to refresh
            NSDictionary *info = [NSDictionary dictionaryWithObject:refresh forKey:@"refresh"];
            [[NSNotificationCenter defaultCenter] postNotificationName:ArticleDidRefreshNotification object:nil userInfo:info];
            [refresh endRefreshing];
        });
    });
}

#pragma mark -
#pragma mark WebView delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        // User tapped something in the UIWebView
        if ([[[request.URL lastPathComponent] pathExtension] isEqualToString:@"jpg"] || [[[request.URL lastPathComponent] pathExtension] isEqualToString:@"png"]|| [[[request.URL lastPathComponent] pathExtension] isEqualToString:@"jpeg"]) {
            // An image was tapped
            // Request URL includes Newsstand, so we assume it's an image clicked within an article.
            [self performSegueWithIdentifier:@"showImageZoom" sender:request.URL];
            return NO;
        } else if ([NIAUHelper validArticleInURL:request.URL]) {
            // It's an internal article link, segue to that article.
            [self segueToArticleInURL:request.URL];
            return NO;
        } else if ([NIAUHelper validIssueInURL:request.URL]) {
            // It's an internal issue link, segue to that issue.
            [self segueToIssueInURL:request.URL];
            return NO;
        } else if (!([[request.URL absoluteString] rangeOfString:@"#"].location == NSNotFound)) {
            // Link is an internal link so just keep loading.
            // TODO: Work out why this isn't jumping to the #anchor
            return YES;
        } else if ([[[request URL] scheme] isEqualToString:@"x-apple-data-detectors"] || [[[request URL] scheme] isEqualToString:@"tel"]) {
            // It's an auto map lookup or telephone number
            return YES;
        } else {
            // A web link was tapped
            // Segue to NIAUWebsiteViewController so users don't leave the app.
            [self performSegueWithIdentifier:@"webLinkTapped" sender:request];
            return NO;
        }
    } else {
        // Normal request, so load the UIWebView
        return YES;
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self.webViewLoadingIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webViewLoadingIndicator stopAnimating];
        [self ensureScrollsToTop: webView];
        [self updateWebViewHeight];
    });
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    DebugLog(@"Error! - %@", error);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    DebugLog(@"Response: %@", response);
}

- (void)ensureScrollsToTop: (UIView *) ensureView
{
    ((UIScrollView *)[[self.bodyWebView subviews] objectAtIndex:0]).scrollsToTop = NO;
}

#pragma mark -
#pragma mark Social sharing

- (IBAction)shareActionTapped:(id)sender
{
    NSMutableArray *itemsToShare = [[NSMutableArray alloc] initWithArray:@[[NSString stringWithFormat:@"I'm reading '%@' from New Internationalist magazine.",self.article.title], self.article.getGuestPassURL.absoluteString]];
    
    // Check if the featured image exists
    if (self.featuredImage.image != nil) {
        [itemsToShare addObject:self.featuredImage.image];
    } else if (self.article.images.count > 0) {
        // Set image to share
        NSString *imageIDOfFirstImage = [[self.article.firstImage objectForKey:@"id"] stringValue];
        UIImage *imageToShare;
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"bigImages"]) {
            // share big image
            imageToShare = [self.article getImageWithID:imageIDOfFirstImage];
        } else {
            // share screen size image
            imageToShare = [self.article getImageWithID:imageIDOfFirstImage andSize:[NIAUHelper screenSize]];
        }
        
        if (imageToShare) {
            [itemsToShare addObject:imageToShare];
        }
    }
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [activityController setValue:[NSString stringWithFormat:@"%@", self.article.title] forKey:@"subject"];
    
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

- (IBAction)handleSwipeLeft:(UISwipeGestureRecognizer *)swipe
{
    // Note: Perform segue called before swipe gesture.
    DebugLog(@"Swiped left!");
}

- (IBAction)handleSwipeRight:(UISwipeGestureRecognizer *)swipe
{
    // Note: Perform segue called before swipe gesture.
    DebugLog(@"Swiped right!");
}

- (void)handleTwoFingerSwipe:(UISwipeGestureRecognizer *)swipe
{
    // Pop back to the root view controller on triple tap
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Segue

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"articleToNextArticle"]) {
        if ([self.article nextArticle]) {
            return YES;
        } else {
            DebugLog(@"Last article!");
            return NO;
        }
    } else if ([identifier isEqualToString:@"articleToPreviousArticle"]) {
        // Remove the current view and go back
        [self.navigationController popViewControllerAnimated:YES];
        return NO;
    } else {
        return YES;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showImageZoom"]) {
        // Load the large version of the image to be zoomed.
        NIAUImageZoomViewController *imageZoomViewController = [segue destinationViewController];
        imageZoomViewController.articleOfOrigin = self.article;
        
        if ([sender isKindOfClass:[UIImageView class]]) {
            // User tapped a native UIImage, so zoom it.
            UIImageView *imageTapped = (UIImageView *)sender;
            imageZoomViewController.imageToLoad = imageTapped.image;
        } else if ([[[sender lastPathComponent] pathExtension] isEqualToString:@"jpg"] || [[[sender lastPathComponent] pathExtension] isEqualToString:@"png"]|| [[[sender lastPathComponent] pathExtension] isEqualToString:@"jpeg"]) {
            // User tapped an image in an article (embedded in a UIWebView), so zoom it.
            imageZoomViewController.imageToLoad = [UIImage imageWithData: [NSData dataWithContentsOfURL:sender]];
        } else {
            // Not sure what the image is, zoom a default
            imageZoomViewController.imageToLoad = [UIImage imageNamed:@"default_article_image.png"];
        }
    } else if ([[segue identifier] isEqualToString:@"articleToCategory"]) {
        NIAUCategoryViewController *categoryViewController = [segue destinationViewController];
        
        // Choose the category tapped.
        categoryViewController.category = [[self.article.categories firstObject] objectForKey:@"name"];
        
    } else if ([[segue identifier] isEqualToString:@"showArticlesInCategory"]) {
        NSIndexPath *selectedIndexPath = [[self.categoryCollectionView indexPathsForSelectedItems] objectAtIndex:0];
        
        NIAUCategoryViewController *categoryViewController = [segue destinationViewController];
        categoryViewController.category = [self.article.categories[selectedIndexPath.row] objectForKey:@"name"];
    } else if ([[segue identifier] isEqualToString:@"webLinkTapped"]) {
        // Send the weblink
        NIAUWebsiteViewController *websiteViewController = [segue destinationViewController];
        websiteViewController.linkToLoad = sender;
        websiteViewController.article = self.article;
    } else if ([[segue identifier] isEqualToString:@"articleToNextArticle"]) {
        // Segue to next article
        NIAUArticleViewController *articleViewController = [segue destinationViewController];
        articleViewController.article = [self.article nextArticle];
    } else if ([[segue identifier] isEqualToString:@"articleToPreviousArticle"]) {
        // Segue to previous article
        NIAUArticleViewController *articleViewController = [segue destinationViewController];
        articleViewController.article = [self.article previousArticle];
    } else if ([[segue identifier] isEqualToString:@"articleDateToTableOfContents"]) {
        // Segue to Table of Contents
        NIAUTableOfContentsViewController *tableOfContentsViewController = [segue destinationViewController];
        tableOfContentsViewController.issue = self.article.issue;
    }
}

- (void)segueToArticleInURL:(NSURL *)url
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:[NSBundle mainBundle]];
    
    NIAUArticleViewController *articleViewController = [storyboard instantiateViewControllerWithIdentifier:@"article"];
    NIAUTableOfContentsViewController *issueViewController = [storyboard instantiateViewControllerWithIdentifier:@"issue"];
    
    NSString *articleIDFromURL = [[url pathComponents] lastObject];
    NSNumber *articleID = [NSNumber numberWithInt:(int)[articleIDFromURL integerValue]];
    NSString *issueIDFromURL = [[url pathComponents] objectAtIndex:2];
    NSNumber *issueID = [NSNumber numberWithInt:(int)[issueIDFromURL integerValue]];
    NSArray *arrayOfIssues = [NIAUIssue issuesFromNKLibrary];
    NSUInteger issueIndexPath = [arrayOfIssues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return ([[obj railsID] isEqualToNumber:issueID]);
    }];
    if (issueIndexPath != NSNotFound) {
        NIAUIssue *issueToLoad = [arrayOfIssues objectAtIndex:issueIndexPath];
        [issueToLoad forceDownloadArticles];
        issueViewController.issue = issueToLoad;
        
        NIAUArticle *articleToLoad = [issueToLoad articleWithRailsID:articleID];
        if (articleToLoad) {
            articleViewController.article = articleToLoad;
            [self.navigationController pushViewController:articleViewController animated:YES];
        } else {
            // Can't find the article, so let's just push the issue.
            [self.navigationController pushViewController:issueViewController animated:YES];
        }
    } else {
        // Can't find that issue..
    }
}

- (void)segueToIssueInURL:(NSURL *)url
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:[NSBundle mainBundle]];
    
    NIAUTableOfContentsViewController *issueViewController = [storyboard instantiateViewControllerWithIdentifier:@"issue"];
    
    NSString *issueIDFromURL = [[url pathComponents] objectAtIndex:2];
    NSNumber *issueID = [NSNumber numberWithInt:(int)[issueIDFromURL integerValue]];
    NSArray *arrayOfIssues = [NIAUIssue issuesFromNKLibrary];
    NSUInteger issueIndexPath = [arrayOfIssues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return ([[obj railsID] isEqualToNumber:issueID]);
    }];
    if (issueIndexPath != NSNotFound) {
        NIAUIssue *issueToLoad = [arrayOfIssues objectAtIndex:issueIndexPath];
        issueViewController.issue = issueToLoad;
        [self.navigationController pushViewController:issueViewController animated:YES];
    } else {
        // Can't find that issue..
    }
}

#pragma mark -
#pragma mark Rotation handling

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // Code to prepare for transition
        
        // Set the margin for the title, teaser, date, and categories to match the CSS
        [self updateTitleViewWidth];
        
        // Update WebView height
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateWebViewHeight];
            [self updateScrollViewContentHeight];
        });
        
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // Handle change
    }];
}

@end
