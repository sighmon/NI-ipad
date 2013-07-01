//
//  NIAUArticle.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NIAUArticle : NSObject

@property(nonatomic, strong) UIImage *image;

@property(nonatomic, weak) NSString *title;
@property(nonatomic, weak) NSString *teaser;
@property(nonatomic, weak) NSString *author;
@property(nonatomic, weak) NSString *body;

@end
