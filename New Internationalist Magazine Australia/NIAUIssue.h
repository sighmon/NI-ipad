//
//  NIAUIssue.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 24/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NewsstandKit/NewsstandKit.h>
#import "NIAUArticle.h"

extern NSString *ArticlesDidUpdateNotification;
extern NSString *ArticlesFailedUpdateNotification;

@interface NIAUIssue : NSObject {
    NSDictionary *dictionary;
    NSArray *articles;
}

-(NSString *)name;
-(NSDate *)publication;

-(NSNumber *)index;
-(NSString *)title;
-(NSString *)editorsLetter;
-(NSString *)editorsName;

+(NSArray *)issuesFromNKLibrary;
+(NIAUIssue *)issueWithDictionary:(NSDictionary *)dict;

-(void)getCoverWithCompletionBlock:(void(^)(UIImage *img))block;

-(NKIssue *)nkIssue;

-(void)requestArticles;
-(NSInteger)numberOfArticles;
-(NIAUArticle *)articleAtIndex:(NSInteger)index;



@end
