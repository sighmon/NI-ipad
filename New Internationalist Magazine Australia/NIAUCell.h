//
//  NIAUCell.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 25/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NIAUCell : UICollectionViewCell

@property (strong, nonatomic) IBOutlet UIImageView *image;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *coverLoadingIndicator;

@end
