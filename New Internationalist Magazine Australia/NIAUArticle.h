//
//  NIAUArticle.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NIAUCache.h"

@class NIAUIssue;

extern NSString *ArticleDidUpdateNotification;
extern NSString *ArticleFailedUpdateNotification;
extern NSString *ImageDidSaveToCacheNotification;

@interface NIAUArticle : NSObject <NSCoding>
{
    NSDictionary *dictionary;
    NIAUCache *bodyCache;
    NIAUCache *featuredImageThumbCache;
    NIAUCache *featuredImageCache;
    NIAUCache *firstImageCache;
    NSMutableDictionary *imageCaches;
}

@property(nonatomic, strong) NIAUIssue *issue;
//Q: does atomic mean what i think it means (threadsafety)?
@property(atomic) BOOL requestingBody;

@property(atomic) BOOL isRailsServerReachable;

-(NSString *)title;
-(NSString *)teaser;
-(NSString *)author;
-(NSArray *)categories;
-(NSNumber *)railsID;
-(NSDate *)publication;
-(BOOL)isKeynote;

-(NIAUArticle *)nextArticle;
-(NIAUArticle *)previousArticle;

-(NSArray *)images;
-(NSURL *)imageCacheURLForId:(NSString *)imageId;
-(NSURL *)imageCacheURLForId:(NSString *)imageId andSize:(CGSize)size;
-(UIImage *)getImageWithID:(NSString *)imageID;
-(UIImage *)getImageWithID:(NSString *)imageID andSize:(CGSize)size;
-(NSDictionary *)firstImage;
-(UIImage *)getFirstImageWithID:(NSString *)imageID andSize:(CGSize)size;
-(void)getFirstImageWithID:(NSString *)imageID andSize:(CGSize)size withCompletionBlock:(void(^)(UIImage *img)) block;

+(NSArray *)articlesFromIssue:(NIAUIssue *)issue;
+(NIAUArticle *)articleWithIssue:(NIAUIssue *)issue andDictionary:(NSDictionary *)dict;
+(NIAUArticle *)articleFromCacheWithIssue:(NIAUIssue *)issue andId:(NSNumber *)index;

-(void)getFeaturedImageWithCompletionBlock:(void(^)(UIImage *img)) block;
-(void)getFeaturedImageThumbWithSize:(CGSize)size andCompletionBlock:(void(^)(UIImage *img)) block;
-(UIImage *)attemptToGetFeaturedImageThumbFromDiskWithSize:(CGSize)size;

-(void)requestBody;
-(NSString *)attemptToGetExpandedBodyFromDisk;

-(void)clearCache;

-(void)deleteArticleBodyFromCache;
-(void)deleteImageWithID:(NSString *)imageID;
-(void)deleteArticleFromCache;

-(NSURL *)getWebURL;

-(NSURL *)getGuestPassURL;

-(BOOL)containsCategoryWithSubstring:(NSString *)substring;

@end

