//
//  NIAUArticle.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUArticle.h"
#import "NIAUIssue.h"
#import "local.h"
#import "UIImage+Resize.h"


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


-(void)setBody:(NSString *)body {
    _body = body;
    [self writeBodyToCache];
}

-(NIAUArticle *)initWithIssue:(NIAUIssue *)_issue andDictionary:(NSDictionary *)_dictionary {
    
    issue = _issue;
    
    dictionary = _dictionary;
    
    
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

-(NSURL *) bodyURL {
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

-(void)writeBodyToCache {
    if(self.body) {
        NSError *error;
        if (![self.body writeToURL:[self bodyURL] atomically:FALSE encoding:NSUTF8StringEncoding error:&error]) {
            NSLog(@"error writing body to cache: %@", error);
        } else {
            NSLog(@"wrote body to cache");
        }
    } else {
        NSLog(@"no body to cache");
    }
}

// this might eventually become it's own class... for now, a class method
+(id)getCachedObjectWithOptions:(NSDictionary*)options andMethods:(NSArray*)methods andDepth:(int)depth{
    __block id object = nil;
    
    [methods enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id (^block)(NSDictionary *) = obj;
        if(depth==0 || idx<depth) {
            object = block(options);
        } else {
            // stop enumerating if we hit the depth test
            *stop = YES;
        }
        // stop enumerating if we have found a non-nil object
        if (object) {
            *stop = YES;
        }
    }];
    
    return object;
}

+(UIImage *)imageThatFitsSize:(CGSize)size fromImage:(UIImage *)image {

    NSLog(@"SCALING IMAGE");
    UIImage *i = [UIImage imageWithCGImage:image.CGImage scale:1 orientation:image.imageOrientation];
    CGSize scaledSize = CGSizeMake(size.width*4, size.height*4);
    i = [i resizedImageWithContentMode:UIViewContentModeScaleAspectFill bounds:scaledSize interpolationQuality:kCGInterpolationDefault];
    return [UIImage imageWithCGImage:i.CGImage scale:4 orientation:image.imageOrientation];
}

-(void)getFeaturedImageWithCompletionBlock:(void(^)(UIImage *img)) block {
    [self getFeaturedImageWithSize:CGSizeZero andCompletionBlock:block];
}

-(void)getFeaturedImageWithSize:(CGSize)size andCompletionBlock:(void(^)(UIImage *img)) block {
    if (cachedFeaturedImageThumb != nil) {
        NSLog(@"Cached fimage %f %f", cachedFeaturedImageThumb.size.height, size.height);
    }
    if (cachedFeaturedImageThumb != nil && !CGSizeEqualToSize(size,CGSizeZero) && CGSizeEqualToSize(size,cachedFeaturedImageThumbSize)) {
        block(cachedFeaturedImageThumb);
    } else {
        NSString *url = [[dictionary objectForKey:@"featured_image"] objectForKey:@"url"];
        NSURL *featuredImageURL = [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
        NSString *featuredImageFileName = [featuredImageURL lastPathComponent];
        NSURL *featuredImageCacheURL = [NSURL URLWithString:featuredImageFileName relativeToURL:[self cacheURL]];
        NSData *imageData = [NSData dataWithContentsOfURL:featuredImageCacheURL];
        UIImage *image = [UIImage imageWithData:imageData];
        
        if(image) {
            NSLog(@"successfully read image from %@",featuredImageCacheURL);
            if(CGSizeEqualToSize(size,CGSizeZero)) {
                block(image);
            } else {
                cachedFeaturedImageThumb = [NIAUArticle imageThatFitsSize:size fromImage:image];
                cachedFeaturedImageThumbSize = size;
                block(cachedFeaturedImageThumb);
            }
        } else {
            NSLog(@"trying to read image from %@",featuredImageURL);
            
            dispatch_async(dispatch_get_global_queue
                           (DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                           ^{
                               NSData *imageData = [NSData dataWithContentsOfURL:featuredImageURL];
                               UIImage *image = [UIImage imageWithData:imageData];
                               if(image) {
                                   NSLog(@"successfully read image from %@",featuredImageURL);
                                   [imageData writeToURL:	featuredImageCacheURL atomically:YES];
                                   // very undry, copied from above
                                   if(CGSizeEqualToSize(size,CGSizeZero)) {
                                       block(image);
                                   } else {
                                       cachedFeaturedImageThumb = [NIAUArticle imageThatFitsSize:size fromImage:image];
                                       cachedFeaturedImageThumbSize = size;
                                       block(cachedFeaturedImageThumb);
                                   }
                               } else {
                                   NSLog(@"failed to read image from %@",featuredImageURL);
                               }
                           });
        }
    }
}

-(void)requestBody {
    if(!requestingBody) {
        requestingBody = TRUE;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            // read from cache first and issue our first update
            NSError *error;
            // update body, without writing to cache
            _body = [NSString stringWithContentsOfURL:[self bodyURL] encoding:NSUTF8StringEncoding error:&error];
            
            if(self.body) {
                NSLog(@"read body from cache");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticleDidUpdateNotification object:self];
                });
            } else {
                NSLog(@"cache miss reading body: %@", error);
            }
            
            NSURL *articleURL = [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@/articles/%@/body", [[self issue] index], [self index]] relativeToURL:[NSURL URLWithString:SITE_URL]];
            NSData *data = [NSData dataWithContentsOfURL:articleURL];
            if(data) {
                self.body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                
                
                //notify
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticleDidUpdateNotification object:self];
                });
            } else {
                // only send failure notification if body is null
                if(!self.body) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:ArticleFailedUpdateNotification object:self];
                    });
                }
            }
            requestingBody = FALSE;
        });

    }
}

- (NSURL *)getWebURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://digital.newint.com.au/issues/%@/articles/%@",self.issue.index, self.index]];
}


@end
