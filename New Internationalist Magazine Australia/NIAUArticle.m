//
//  NIAUArticle.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUArticle.h"
#import "NIAUIssue.h"
#import "NSData+Cookieless.h"
#import "local.h"
//#import "UIImage+Resize.h"


NSString *ArticleDidUpdateNotification = @"ArticleDidUpdate";
NSString *ArticleFailedUpdateNotification = @"ArticleFailedUpdate";


@implementation NIAUArticle

// AHA: this makes getters/setters for these readonly properties without exposing them publically
@synthesize issue;



-(NSString *)author {
    return [dictionary objectForKey:@"author"];
}

-(NSString *)teaser {
    return [dictionary objectForKey:@"teaser"];
}

-(NSString *)title {
    return [dictionary objectForKey:@"title"];
}

-(NSNumber *)index {
    return [dictionary objectForKey:@"id"];
}

-(NSArray *)categories {
    return [dictionary objectForKey:@"categories"];
}


-(NIAUCache *)buildFeaturedImageCache {
    __weak NIAUArticle *weakSelf = self;
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[@"featuredImage"];
    } andWriteBlock:^(id object, id options, id state) {
        state[@"featuredImage"] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        NSData *imageData = [NSData dataWithContentsOfURL:[weakSelf featuredImageCacheURL]];
        return [UIImage imageWithData:imageData];
    } andWriteBlock:^(id object, id options, id state) {
        [UIImagePNGRepresentation(object) writeToURL:[weakSelf featuredImageCacheURL] atomically:YES];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSData *imageData = [NSData dataWithContentsOfCookielessURL:[weakSelf featuredImageURL]];
        return [UIImage imageWithData:imageData];
    } andWriteBlock:^(id object, id options, id state) {
        // noop
    }]];
    return cache;
}

-(NIAUCache *)buildFeaturedImageThumbCache {
    __weak NIAUArticle *weakSelf = self;
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        id entry = state[@"size"];
        if(!entry) return nil;
        CGSize cachedSize = [(NSValue *)entry CGSizeValue];
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        if(CGSizeEqualToSize(cachedSize,size)) {
            return state[@"thumb"];
        } else {
            return nil;
        }
    } andWriteBlock:^(id object, id options, id state) {
        state[@"size"]=options[@"size"];
        state[@"thumb"]=object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        UIImage *image = [weakSelf getFeaturedImageThumbFromDisk];
        if(image && CGSizeEqualToSize([image size], size)) {
            return image;
        } else {
            return nil;
        }
    } andWriteBlock:^(id object, id options, id state) {
        // writeFeaturedImageThumbToDisk
        [UIImagePNGRepresentation(object) writeToURL:[self featuredImageThumbCacheURL] atomically:YES];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"generate" withReadBlock:^id(id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        return [weakSelf generateFeaturedImageThumbWithSize:size];
    } andWriteBlock:^(id object, id options, id state) {
        // no op
    }]];
    return cache;
}

-(NIAUCache *)buildBodyCache {
    __weak NIAUArticle *weakSelf = self;
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[@"body"];
    } andWriteBlock:^(id object, id options, id state) {
        state[@"body"] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        return [NSString stringWithContentsOfURL:[weakSelf bodyCacheURL] encoding:NSUTF8StringEncoding error:nil];
    } andWriteBlock:^(id object, id options, id state) {
        [(NSString*)object writeToURL:[self bodyCacheURL] atomically:FALSE encoding:NSUTF8StringEncoding error:nil];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSData *data = [self downloadArticleBodyWith: [[weakSelf issue] index] and: [weakSelf index]];
        if(data)
            return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        else return nil;
    } andWriteBlock:^(id object, id options, id state) {
        // no op
    }]];
    return cache;
}

- (NSData *)downloadArticleBodyWith: (NSNumber *)issueIndex and: (NSNumber *)articleIndex
{
    // POSTs the receipt to Rails, and then onto iTunes to check for a valid purchase
    // If there's a valid purchase, it returns the article body
    
    NSURL *articleURL = [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@/articles/%@/body", issueIndex, articleIndex] relativeToURL:[NSURL URLWithString:SITE_URL]];

    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    
    NSString *base64receipt = [receiptData base64EncodedStringWithOptions:0];
    NSData *postData = [base64receipt dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:articleURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];

    NSError *error;
    NSHTTPURLResponse *response;
    
//    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    int statusCode = [response statusCode];
    NSString *data = [[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding];
    if (!error && statusCode >= 200 && statusCode < 300) {
        NSLog(@"Response from Rails: %@", data);
    } else {
        NSLog(@"Rails returned statusCode: %d\n an error: %@\nAnd data: %@", statusCode, error, data);
        responseData = nil;
    }
    
    return responseData;
}

-(NIAUArticle *)initWithIssue:(NIAUIssue *)_issue andDictionary:(NSDictionary *)_dictionary {
    self = [super init];
    if(self) {
        issue = _issue;
        dictionary = _dictionary;
        
        featuredImageCache = [self buildFeaturedImageCache];
        featuredImageThumbCache = [self buildFeaturedImageThumbCache];
        bodyCache = [self buildBodyCache];
    }
    
    return self;
}

+(NIAUArticle *)articleWithIssue:(NIAUIssue *)_issue andDictionary:(NSDictionary *)_dictionary {
    
    NIAUArticle *article = [[NIAUArticle alloc] initWithIssue:_issue andDictionary: _dictionary];

    [article writeToCache];

    return article;
}


// Q: is providing all of these class methods evil?
// alternate solution could be to create a skeleton issue then call -bodyURL
+(NSURL *) cacheURLWithIssue:(NIAUIssue *)issue andId:(NSNumber *)index {
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/", index] relativeToURL:issue.nkIssue.contentURL];
}

-(NSURL *) cacheURL {
    return [NIAUArticle cacheURLWithIssue:[self issue] andId:[self index]];
}

+(NSURL *) metadataURLWithIssue:(NIAUIssue *)issue andId:(NSNumber *)index {
    return [NSURL URLWithString:@"article.json" relativeToURL:[NIAUArticle cacheURLWithIssue:issue andId:index]];
}

-(NSURL *) metadataURL {
    return [NIAUArticle metadataURLWithIssue:[self issue] andId:[self index]];
}

-(NSURL *) bodyCacheURL {
    return [NSURL URLWithString:@"body.html" relativeToURL:[self cacheURL]];
}

//TODO: call this once for each article in the issue metadata
+(NIAUArticle *)articleFromCacheWithIssue:(NIAUIssue *)_issue andId:(NSNumber *)_id {
   
    NSData *data = [NSData dataWithContentsOfURL:[self metadataURLWithIssue:_issue andId:_id]];
    NSError *error;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];

    // call the init directly to avoid saving back to cache
    return [[NIAUArticle alloc] initWithIssue:_issue andDictionary: dictionary];

}

+(NSArray *)articlesFromIssue:(NIAUIssue *)_issue {
    NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
    NSMutableArray *articles = [NSMutableArray array];
    NSArray *keys = @[NSURLIsDirectoryKey,NSURLNameKey];
    NSError *error;
    for (NSURL *url in [[NSFileManager defaultManager] contentsOfDirectoryAtURL:_issue.nkIssue.contentURL includingPropertiesForKeys:keys options:0 error:&error]) {
        NSDictionary *properties = [url resourceValuesForKeys:keys error:&error];
        if ([[properties objectForKey:NSURLIsDirectoryKey] boolValue]==YES) {
            [articles addObject:[self articleFromCacheWithIssue:_issue andId:[nf numberFromString:[properties objectForKey:NSURLNameKey]]]];
        }
    }
    return articles;
}

-(void)writeToCache {
    NSLog(@"TODO: %s", __PRETTY_FUNCTION__);
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtURL:[self cacheURL] withIntermediateDirectories:TRUE attributes:nil error:&error]) {
        
        NSLog(@"writing article to cache: %@",[[self metadataURL] absoluteString]);
        
        NSOutputStream *os = [NSOutputStream outputStreamWithURL:[self metadataURL] append:FALSE];
        
        [os open];
        NSError *error;
        if ([NSJSONSerialization writeJSONObject:dictionary toStream:os options:0 error:&error]<=0) {
            NSLog(@"Error writing JSON file");
        }
        [os close];
        
    } else {
        NSLog(@"error creating cache dir: %@",error);
    }
}

-(NSURL *)featuredImageThumbCacheURL {
    NSString *featuredImageBaseName = [[[self featuredImageURL] lastPathComponent] stringByDeletingPathExtension];
    return [NSURL URLWithString:[featuredImageBaseName stringByAppendingPathExtension:@"_thumb.png"] relativeToURL:[self cacheURL]];
}

-(UIImage *)getFeaturedImageThumbFromDisk {
    NSData *thumbData = [NSData dataWithContentsOfURL:[self featuredImageThumbCacheURL]];
    return [UIImage imageWithData:thumbData scale:[[UIScreen mainScreen] scale]];
}

-(UIImage *)generateFeaturedImageThumbWithSize:(CGSize)thumbSize {
    UIImage *image = [self getFeaturedImage];
    
    // don't make blank thumbnails ;)
    if(!image) return nil;
    
    UIGraphicsBeginImageContextWithOptions(thumbSize, NO, 0.0f);
    float thumbAspect = thumbSize.width/thumbSize.height;
    float imageAspect = [image size].width/[image size].height;
    CGRect drawRect;
    if(imageAspect > thumbAspect) {
        // image is wider than thumb
        float drawWidth = thumbSize.height*imageAspect;
        drawRect = CGRectMake(-(drawWidth-thumbSize.width)/2.0, 0.0, drawWidth, thumbSize.height);
    } else {
        // image is taller than thumb
        float drawHeight = thumbSize.width/imageAspect;
        drawRect = CGRectMake(0.0, -(drawHeight-thumbSize.height)/2.0, thumbSize.width, drawHeight);
    }
    [image drawInRect:drawRect];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return thumb;
}



-(void)getFeaturedImageThumbWithSize:(CGSize)size andCompletionBlock:(void (^)(UIImage *))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       UIImage *thumb = [self getFeaturedImageThumbWithSize:size];
                       // run the block on the main queue so it can do ui stuff
                       dispatch_async(dispatch_get_main_queue(), ^{
                           block(thumb);
                       });
                   });
}

-(UIImage *)getFeaturedImageThumbWithSize:(CGSize)size {
    return [featuredImageThumbCache readWithOptions:@{@"size":[NSValue valueWithCGSize:size]}];
}

-(UIImage *)attemptToGetFeaturedImageThumbFromDiskWithSize:(CGSize)size {
    return [featuredImageThumbCache readWithOptions:@{@"size":[NSValue valueWithCGSize:size]} stoppingAt:@"generate"];
}


-(void)getFeaturedImageWithCompletionBlock:(void(^)(UIImage *img)) block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       UIImage *image = [self getFeaturedImage];
                       // run the block on the main queue so it can 	do ui stuff
                       dispatch_async(dispatch_get_main_queue(), ^{
                           block(image);
                       });

                   });
}

-(NSURL *) featuredImageURL {
    NSString *url = [[dictionary objectForKey:@"featured_image"] objectForKey:@"url"];
    if ((url != (id)[NSNull null]) && url) {
        return [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
    } else {
//        return [[NSBundle mainBundle] URLForResource:@"default_article_image_table_view" withExtension:@"png"];
        return nil;
    }
}

-(NSURL *) featuredImageCacheURL {
    NSString *featuredImageFileName = [[self featuredImageURL]lastPathComponent];
    return [NSURL URLWithString:featuredImageFileName relativeToURL:[self cacheURL]];
}

-(UIImage *)getFeaturedImage {
    return [featuredImageCache readWithOptions:nil];
}

-(NSString *)attemptToGetBodyFromDisk {
    return [bodyCache readWithOptions:nil stoppingAt:@"net"];
}

-(void)requestBody {
    if(!self.requestingBody) {
        self.requestingBody = TRUE;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            
            id body = [bodyCache readWithOptions:nil];
//            NSLog(@"requestBody. body==%@",body);

            if(body) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticleDidUpdateNotification object:self];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticleFailedUpdateNotification object:self];
                });
            }
            self.requestingBody = FALSE;
        });
    }
}

- (NSURL *)getWebURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@/articles/%@",self.issue.index, self.index] relativeToURL:[NSURL URLWithString:SITE_URL]];
}


@end
