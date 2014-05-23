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
#import "NSData+Cookieless.h"
#import "local.h"
#import "NIAUPublisher.h"

extern NSString *ArticlesDidUpdateNotification;
extern NSString *ArticlesFailedUpdateNotification;

@interface NIAUIssue : NSObject <NSCoding>
{
    NSDictionary *dictionary;
    NSArray *articles;
    BOOL requestingArticles;
    BOOL requestingCover;
    NIAUCache *coverThumbCache;
    NIAUCache *coverCache;
    NIAUCache *categoriesSortedCache;
    NIAUCache *articlesSortedCache;
}

-(NSString *)name;
-(NSDate *)publication;

-(NSNumber *)railsID;
-(NSString *)title;
-(NSString *)editorsLetter;
-(NSString *)editorsName;

-(NSArray *)featureArticles;
-(NSArray *)agendaArticles;
-(NSArray *)currentsArticles;
-(NSArray *)mixedMediaArticles;
-(NSArray *)opinionArticles;
-(NSArray *)alternativesArticles;
-(NSArray *)regularArticles;
-(NSArray *)uncategorisedArticles;
-(NSArray *)sortedCategories;
-(NSArray *)sortedArticles;

-(NSArray *)getCategoriesSorted;
-(NSArray *)getCategoriesSortedStartingAt:(NSString *)startingAt;
-(NSArray *)getArticlesSorted;
-(NSArray *)getArticlesSortedStartingAt:(NSString *)startingAt;

+(NSArray *)issuesFromNKLibrary;
+(NIAUIssue *)issueWithDictionary:(NSDictionary *)dict;
+(NIAUIssue *)issueWithUserInfo:(NSDictionary *)dict;

-(void)getCoverWithCompletionBlock:(void(^)(UIImage *img))block;

-(void)getCoverThumbWithSize:(CGSize)size andCompletionBlock:(void (^)(UIImage *))block;

-(UIImage *)attemptToGetCoverThumbFromMemoryForSize:(CGSize)size;

-(void)getEditorsImageWithCompletionBlock:(void(^)(UIImage *img))block;

-(NKIssue *)nkIssue;

-(void)requestArticles;
-(void)forceDownloadArticles;
-(NSInteger)numberOfArticles;
-(NIAUArticle *)articleAtIndex:(NSInteger)index;
-(NIAUArticle *)articleWithRailsID:(NSNumber *)railsID;

-(NSURL *)getWebURL;

-(void)clearCache;

@end
