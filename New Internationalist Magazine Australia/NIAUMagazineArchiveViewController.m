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

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section;
{
    return [[NIAUPublisher getInstance] numberOfIssues];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    // we're going to use a custom UICollectionViewCell, which will hold an image and its label
    //
    NIAUCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kCellID forIndexPath:indexPath];
    
    // make the cell's title the actual NSIndexPath value
    // cell.label.text = [NSString stringWithFormat:@"{%ld,%ld}", (long)indexPath.row, (long)indexPath.section];
    
    
    
    // load the image for this cell
    [[NIAUPublisher getInstance] setCoverOfIssueAtIndex:indexPath.row completionBlock:^(UIImage *img) {
        dispatch_async(dispatch_get_main_queue(), ^{
            //UITableViewCell *cell = [table_ cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:0]];
            //UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
            //imageView.image=img;
            cell.image.image = img;
        });
    }];

    //NSString *imageToLoad = [NSString stringWithFormat:@"%d.png", indexPath.row];
    //cell.image.image = [UIImage imageNamed:imageToLoad];
    
    // Shadow for the cell (slows performance!)
//    cell.layer.shadowColor = [UIColor blackColor].CGColor;
//    cell.layer.shadowOffset = CGSizeMake(0, 2);
//    cell.layer.shadowOpacity = 0.5;
//    cell.layer.shadowRadius = 3.0;
//    cell.clipsToBounds = NO;
    
    // Using a border instead for smoother scrolling.
    cell.layer.borderColor = [UIColor colorWithRed:242/255.0f green:242/255.0f blue:242/255.0f alpha:1.0f].CGColor;
    cell.layer.borderWidth = 1.0;
    
    return cell;
}

// the user tapped a collection item, load and set the image on the detail view controller

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showTableOfContents"])
    {
        NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] objectAtIndex:0];
        
        // load the image, to prevent it from being cached we use 'initWithContentsOfFile'
        NSString *imageNameToLoad = [NSString stringWithFormat:@"%d", selectedIndexPath.row];
        NSString *pathToImage = [[NSBundle mainBundle] pathForResource:imageNameToLoad ofType:@"png"];
        UIImage *image = [[UIImage alloc] initWithContentsOfFile:pathToImage];
        NIAUTableOfContentsViewController *tableOfContentsViewController = [segue destinationViewController];
        tableOfContentsViewController.cover = image;
    }
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
