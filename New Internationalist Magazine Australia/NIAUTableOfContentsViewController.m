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
    
    [self.issue getCoverWithCompletionBlock:^(UIImage *img) {
        self.imageView.image = img;
    }];
    
    // Shadow for the cover
    
    self.imageView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.imageView.layer.shadowOffset = CGSizeMake(0, 2);
    self.imageView.layer.shadowOpacity = 0.3;
    self.imageView.layer.shadowRadius = 3.0;
    self.imageView.clipsToBounds = NO;
    
    self.labelTitle.text = self.issue.title;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMMM yyyy"];
    self.labelNumberAndDate.text = [NSString stringWithFormat: @"%@ - %@", self.issue.name, [dateFormatter stringFromDate:self.issue.publication]];
    // self.labelDate.text = [dateFormatter stringFromDate:self.issue.publication];
    self.labelEditor.text = self.issue.editorsName;
    self.editorsLetterTextView.text = self.issue.editorsLetter;
    
    NSLog(@"TODO: Get the real editor's image.");
    [self.editorImageView setImage:[UIImage imageNamed:@"default_editors_photo.png"]];
    
    // Draw a round mask for the editor's photo
    
    self.editorImageView.layer.masksToBounds = YES;
    self.editorImageView.layer.cornerRadius = self.editorImageView.bounds.size.width / 2.;
    
    // Wrap the text around the editor's photo
    
    CGRect editorImageViewRect = [self.editorsLetterTextView convertRect:self.editorImageView.frame fromView:self.view];
    
    // self.editorsLetterTextView.textContainer.exclusionPaths = @[[UIBezierPath bezierPathWithRoundedRect:editorImageViewRect cornerRadius:self.editorImageView.layer.cornerRadius]];
    // TODO: Work out how to only exclude words not characters. For now I'll just use a square exclusionPath.
    
    self.editorsLetterTextView.textContainer.exclusionPaths = @[[UIBezierPath bezierPathWithRect:editorImageViewRect]];
}

- (void)viewDidLayoutSubviews
{
    // Set the scrollView content height to the editorsLetterTextView.
    
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.frame.size.width, self.editorsLetterTextView.frame.origin.y + self.editorsLetterTextView.frame.size.height)];
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
    }
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

@end
