//
//  NIAUMagazineArchiveViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 25/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUMagazineArchiveViewController.h"
#import "NIAUCell.h"
#import "NIAUTableOfContentsViewController.h"
#import "NIAUPublisher.h"

NSString *kCellID = @"magazineCellID";              // UICollectionViewCell storyboard id

@interface NIAUMagazineArchiveViewController ()

@end

@implementation NIAUMagazineArchiveViewController

- (void)dealloc {
    // to avoid potential crashes
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

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
    
    // TODO: this second request is causing troubles
    if([[NIAUPublisher getInstance] isReady]) {
        [self showIssues];
    } else {
        [self loadIssues];
    }
    
    self.title = @"Archive";
    [self sendGoogleAnalyticsStats];
}

- (void)sendGoogleAnalyticsStats
{
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:self.title];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createAppView] build]];
}

// doublehandling from NIAUViewController...
-(void)loadIssues {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherReady:) name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publisherFailed:) name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];
    [[NIAUPublisher getInstance] requestIssues];
}

-(void)publisherReady:(NSNotification *)not {
    // might recieve this more than once
    //[[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    //[[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];
    [self showIssues];
}

-(void)showIssues {
    [self.collectionView reloadData];
}

-(void)publisherFailed:(NSNotification *)not {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];
    NSLog(@"%@",not);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:@"Cannot get issues from publisher server."
                                                   delegate:nil
                                          cancelButtonTitle:@"Close"
                                          otherButtonTitles:nil];
    [alert show];
    alert.delegate = nil;
    //[alert release];
    //[self.navigationItem setRightBarButtonItem:refreshButton];
}

#pragma mark -
#pragma mark CollectionViewDelegate

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section;
{
    return [[NIAUPublisher getInstance] numberOfIssues];
}

// AHA: UICollectionViewController implements UICollectionViewDataSource where this method is defined.
- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    // we're going to use a custom UICollectionViewCell, which will hold an image and its label
    //
    NIAUCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kCellID forIndexPath:indexPath];
    
    // make the cell's title the actual NSIndexPath value
    // cell.label.text = [NSString stringWithFormat:@"{%ld,%ld}", (long)indexPath.row, (long)indexPath.section];
    
    // load the image for this cell
    
    CGSize size = CGSizeMake(0,0);
    
    size = [self calculateCellSizeForScreenSize:self.view.frame.size];
    
    // TODO: need to do this in a background thread, as the cover image is large and causing lag!
//    cell.image.image = [NIAUHelper imageWithRoundedCornersSize:3. usingImage:[[[NIAUPublisher getInstance] issueAtIndex:indexPath.row] attemptToGetCoverThumbFromMemoryForSize:size]];
    
    cell.image.image = nil;
    
    if (cell.image.image == nil) {
        // Start the loading indicator
        cell.image.image = [UIImage imageNamed:@"ni-logo-grey.png"];
        [cell.coverLoadingIndicator startAnimating];
        
        [[[NIAUPublisher getInstance] issueAtIndex:indexPath.row] getCoverThumbWithSize:size andCompletionBlock:^(UIImage *img) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // Is cell is still in view
                NIAUCell *updateCell = (id)[self.collectionView cellForItemAtIndexPath:indexPath];
                
                if (img && [[self.collectionView visibleCells] containsObject:updateCell]) {
                    
//                    NSLog(@"Cell: (%f,%f), IndexPath: %ld", updateCell.frame.origin.x, updateCell.frame.origin.y, (long)indexPath.row);
                    if (updateCell) {
                        [updateCell.coverLoadingIndicator stopAnimating];
                        [updateCell.image setAlpha:0.0];
                        [updateCell.image setImage:[NIAUHelper imageWithRoundedCornersSize:3. usingImage:img]];
                        [UIView animateWithDuration:0.3 animations:^{
                            [updateCell.image setAlpha:1.0];
                        }];
                    }
                }
            });
        }];
    }
    
    // Set a border for the magazine covers
    //    cell.layer.borderColor = [UIColor colorWithRed:242/255.0f green:242/255.0f blue:242/255.0f alpha:1.0f].CGColor;
    //    cell.layer.borderWidth = 1.0;
    
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout  *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self calculateCellSizeForScreenSize:self.view.frame.size];
}

- (CGSize)calculateCellSizeForScreenSize:(CGSize)size
{
    BOOL landscape = UIDeviceOrientationIsLandscape(self.interfaceOrientation);
    int columns = 0;
    
    if (landscape) {
        columns = 5;
    } else {
        if (IS_IPAD()) {
            columns = 4;
        } else {
            columns = 3;
        }
    }
    CGSize returnSize = CGSizeMake((size.width/columns)-2, size.width*1415/(1000*columns));
//    NSLog(@"Calculated size: %f, %f", returnSize.width, returnSize.height);
    return returnSize;
}

// the user tapped a collection item, load and set the image on the detail view controller

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showTableOfContents"])
    {
        NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] objectAtIndex:0];
        
        NIAUTableOfContentsViewController *tableOfContentsViewController = [segue destinationViewController];
        tableOfContentsViewController.issue = [[NIAUPublisher getInstance] issueAtIndex:selectedIndexPath.row];
    }
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark - Rotation handling

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.collectionView performBatchUpdates:nil completion:nil];
}

//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
//{
//    ((UICollectionViewFlowLayout *)self.collectionViewLayout).itemSize = [self calculateCellSizeForScreenSize:self.view.frame.size];
//    
//    [self.collectionViewLayout invalidateLayout];
//}

@end
