//
//  NIAUArticle.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NIAUIssue;

extern NSString *ArticleDidUpdateNotification;
extern NSString *ArticleFailedUpdateNotification;

@interface NIAUArticle : NSObject {
    NSString *body;
    NSDictionary *dictionary;
}

@property(nonatomic, strong) NIAUIssue *issue;

-(NSString *)title;
-(NSString *)teaser;
-(NSString *)author;
-(NSString *)body;

+(NIAUArticle *)articleWithIssue:(NIAUIssue *)issue andDictionary:(NSDictionary *)dict;

-(void)requestBody;

@end
