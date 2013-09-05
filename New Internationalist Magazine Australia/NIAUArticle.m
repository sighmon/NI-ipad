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

// can't seem to use this typedef anywhere...
//typedef id (^MethodBlock(id));

// this might eventually become it's own class... for now, a class method
+(id)getObjectWithOptions:(NSDictionary*)options andDepth:(int)depth usingBlocks:(NSArray*)blocks{
    __block id object = nil;
    
    [blocks enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id (^block)(id) = obj;
        if(depth<0 || idx<=depth) {
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

-(NSURL *)featuredImageThumbCacheURL {
    NSString *url = [[dictionary objectForKey:@"featured_image"] objectForKey:@"url"];
    NSURL *featuredImageURL = [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
    NSString *featuredImageBaseName = [[featuredImageURL lastPathComponent] stringByDeletingPathExtension];
    return [NSURL URLWithString:[featuredImageBaseName stringByAppendingPathExtension:@"_thumb.png"] relativeToURL:[self cacheURL]];
}

-(void)writeFeaturedImageThumbToDisk{
    [UIImagePNGRepresentation(cachedFeaturedImageThumb) writeToURL:[self featuredImageThumbCacheURL] atomically:YES];
}

-(UIImage *)getFeaturedImageThumbFromDisk {
    NSData *thumbData = [NSData dataWithContentsOfURL:[self featuredImageThumbCacheURL]];
    return [UIImage imageWithData:thumbData scale:[[UIScreen mainScreen] scale]];
}

-(UIImage *)generateFeaturedImageThumbWithSize:(CGSize)thumbSize {
    UIImage *image = [self getFeaturedImage];

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
    return [self getFeaturedImageThumbWithSize:size stoppingAtDepth:-1];
}

-(UIImage *)attemptToGetFeaturedImageThumbFromDiskWithSize:(CGSize)size {
    return [self getFeaturedImageThumbWithSize:size stoppingAtDepth:1];
}

// our cache strategy in a nutshell
-(UIImage *)getFeaturedImageThumbWithSize:(CGSize)size stoppingAtDepth:(int)depth {
    
    return [self.class getObjectWithOptions:@{@"size": [NSValue valueWithCGSize:size]} andDepth:depth
                                usingBlocks:@[
                                              // get thumb from memory
                                              ^id(id opts){
        NSLog(@"get thumb from memory");
        if(CGSizeEqualToSize(cachedFeaturedImageThumbSize,
                             [opts[@"size"] CGSizeValue])) {
            return cachedFeaturedImageThumb;
        }
        return nil;
    },
                                               // get thumb from disk
                                               ^id(id opts){
        NSLog(@"get thumb from disk");
        UIImage *image = [self getFeaturedImageThumbFromDisk];
        CGSize size = [opts[@"size"] CGSizeValue];
        if(image && CGSizeEqualToSize([image size],
                                      size)) {
            cachedFeaturedImageThumb = image;
            cachedFeaturedImageThumbSize = size;
            return image;
        }
        NSLog(@"thumb disk cache miss");
        if(image) NSLog(@"sizes: %@ vs %@",[NSValue valueWithCGSize:size],[NSValue valueWithCGSize:[image size]]);
        return nil;
    },
                                               // generate thumb
                                               ^id(id opts){
        NSLog(@"generate thumb");
        UIImage *image = [self generateFeaturedImageThumbWithSize:[opts[@"size"] CGSizeValue]];
        if(image) {
            cachedFeaturedImageThumb = image;
            cachedFeaturedImageThumbSize = size;
            [self writeFeaturedImageThumbToDisk];
            return image;
        }
        return nil;
    }
                                               ]];
}


-(void)getFeaturedImageWithCompletionBlock:(void(^)(UIImage *img)) block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
                   ^{
                       block([self getFeaturedImage]);
                   });
}

//TODO: restructure to use the same pattern as FeaturedImageThumb
-(UIImage *)getFeaturedImage {
    NSString *url = [[dictionary objectForKey:@"featured_image"] objectForKey:@"url"];
    NSURL *featuredImageURL = [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
    NSString *featuredImageFileName = [featuredImageURL lastPathComponent];
    NSURL *featuredImageCacheURL = [NSURL URLWithString:featuredImageFileName relativeToURL:[self cacheURL]];
    NSData *imageData = [NSData dataWithContentsOfURL:featuredImageCacheURL];
    UIImage *image = [UIImage imageWithData:imageData];
    
    if(image) {
        NSLog(@"successfully read image from %@",featuredImageCacheURL);
        return image;
    } else {
        NSLog(@"trying to read image from %@",featuredImageURL);
        
        NSData *imageData = [NSData dataWithContentsOfURL:featuredImageURL];
        UIImage *image = [UIImage imageWithData:imageData];
        if(image) {
            NSLog(@"successfully read image from %@",featuredImageURL);
            [imageData writeToURL:	featuredImageCacheURL atomically:YES];
            return image;
        } else {
            NSLog(@"failed to read image from %@",featuredImageURL);
            return nil;
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
