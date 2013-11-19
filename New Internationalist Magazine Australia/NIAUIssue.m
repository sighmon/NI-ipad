//
//  NIAUIssue.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 24/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUIssue.h"
#import "NSData+Cookieless.h"
#import "local.h"

NSString *ArticlesDidUpdateNotification = @"ArticlesDidUpdate";
NSString *ArticlesFailedUpdateNotification = @"ArticlesFailedUpdate";


@implementation NIAUIssue


-(id)init {
    if (self = [super init]) {
        requestingArticles = false;
        
        coverCache = [self buildCoverCache];
        coverThumbCache = [self buildCoverThumbCache];
    }
    return self;
}

- (NSURL *)coverURL
{
    NSString *url = [[[dictionary objectForKey:@"cover"] objectForKey:@"png"] objectForKey:@"url"];
    // online location of cover
    return [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
}

- (NSURL *)coverCacheURL
{
    NSString *coverFileName = [[self coverURL] lastPathComponent];
    // local URL to where the cover is/would be stored
    return [NSURL URLWithString:coverFileName relativeToURL:[self.nkIssue contentURL]];
}

- (NSURL *)coverCacheURLForSize:(CGSize)size
{
    NSString *coverFileName = [[self coverURL] lastPathComponent];
    // local URL to where the cover is/would be stored
    NSString *coverCacheFileName = [coverFileName stringByAppendingPathExtension:[NSString stringWithFormat:@".thumb%fx%f.png",size.width,size.height]];
    return [NSURL URLWithString:coverCacheFileName relativeToURL:[self.nkIssue contentURL]];
}

- (NIAUCache *)buildCoverCache
{
    __weak NIAUIssue *weakSelf = self;
    
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[@"cover"];
    } andWriteBlock:^(id object, id options, id state) {
        state[@"cover"] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        // TODO: Pull the CGSize out of the options string.
        NSLog(@"trying to read cached image from %@",[weakSelf coverCacheURL]);
        return [UIImage imageWithData:[NSData dataWithContentsOfURL:[weakSelf coverCacheURL]]];
    } andWriteBlock:^(id object, id options, id state) {
        [UIImagePNGRepresentation(object) writeToURL:[weakSelf coverCacheURL] atomically:YES];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSLog(@"NET trying to read cached image from %@",[[weakSelf coverURL] absoluteURL]);
        NSData *imageData = [NSData dataWithContentsOfCookielessURL:[weakSelf coverURL]];
        return [UIImage imageWithData:imageData];
    } andWriteBlock:^(id object, id options, id state) {
        // Nothing to do, can't write to the net.
    }]];
    return cache;
}

- (NIAUCache *)buildCoverThumbCache
{
    __weak NIAUIssue *weakSelf = self;
    
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[options[@"size"]];
    } andWriteBlock:^(id object, id options, id state) {
        state[options[@"size"]] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        NSLog(@"trying to read cached image from %@",[weakSelf coverCacheURLForSize:size]);
        return [UIImage imageWithData:[NSData dataWithContentsOfURL:[weakSelf coverCacheURLForSize:size]]];
    } andWriteBlock:^(id object, id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        [UIImagePNGRepresentation(object) writeToURL:[weakSelf coverCacheURLForSize:size] atomically:YES];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"generate" withReadBlock:^id(id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        return [weakSelf generateCoverCacheThumbWithSize:size];
    } andWriteBlock:^(id object, id options, id state) {
        // Nothing to do, can't write to the net.
    }]];
    return cache;
}

-(UIImage *)getCoverImage {
    return [coverCache readWithOptions:nil];
}

-(UIImage *)generateCoverCacheThumbWithSize:(CGSize)thumbSize {
    UIImage *image = [self getCoverImage];
    
    // don't make blank thumbnails ;)
    if(!image) return nil;
    
    UIGraphicsBeginImageContextWithOptions(thumbSize, NO, 0.0f);
    float thumbAspect = thumbSize.width/thumbSize.height;
    float imageAspect = [image size].width/[image size].height;
    CGRect drawRect;
    if(imageAspect > thumbAspect) {
        // image is wider than thumb
        float drawHeight = thumbSize.width/imageAspect;
        drawRect = CGRectMake(0.0, -(drawHeight-thumbSize.height)/2.0, thumbSize.width, drawHeight);
    } else {
        // image is taller than thumb
        float drawWidth = thumbSize.height*imageAspect;
        drawRect = CGRectMake(-(drawWidth-thumbSize.width)/2.0, 0.0, drawWidth, thumbSize.height);
    }
    [image drawInRect:drawRect];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return thumb;
}

-(void)getCoverThumbWithSize:(CGSize)size andCompletionBlock:(void (^)(UIImage *))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       UIImage *thumb = [self getCoverThumbWithSize:size];
                       // run the block on the main queue so it can do ui stuff
                       dispatch_async(dispatch_get_main_queue(), ^{
                           block(thumb);
                       });
                   });
}

-(UIImage *)getCoverThumbWithSize:(CGSize)size {
    return [coverThumbCache readWithOptions:@{@"size":[NSValue valueWithCGSize:size]}];
}

//build from dictionary (and write to cache)
// called when downloading issues.json from website

-(NIAUIssue *)initWithDictionary:(NSDictionary *)dict {
    if (self = [self init]) {
        dictionary = dict;
        
        [self addToNewsstand];
        [self writeToCache];
    }
    return self;
}

+(NIAUIssue *)issueWithDictionary:(NSDictionary *)dict {
    return [[NIAUIssue alloc] initWithDictionary:dict];
}

//build from NKIssue object (read from cache)
// called when building from cache

-(NIAUIssue *)initWithNKIssue:(NKIssue *)issue {
    if (self = [self init]) {
        NSError *error;
        // local json URL
        NSURL *jsonURL = [NSURL URLWithString:@"issue.json" relativeToURL:[issue contentURL]];
        NSData *data = [NSData dataWithContentsOfURL:jsonURL];
        
        if (data) {
            dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            return self;
        } else {
            return nil;
        }
    }
    return self;
}

+(NIAUIssue *)issueWithNKIssue:(NKIssue *)issue {
    return [[NIAUIssue alloc] initWithNKIssue:issue];
}

+(NSArray *)issuesFromNKLibrary {
    NKLibrary *nkLibrary = [NKLibrary sharedLibrary];
    // Q: since we know the size at creation can this be a normal NSArray?
    NSMutableArray *tmpIssues = [NSMutableArray arrayWithCapacity:[[nkLibrary issues] count]];
    [[nkLibrary issues] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NKIssue *nkIssue = (NKIssue *)obj;
        NIAUIssue *issue = [NIAUIssue issueWithNKIssue:nkIssue];
        if (issue) {
            [tmpIssues addObject:issue];
        }
        
    }];
    return tmpIssues;
}


-(NKIssue *)nkIssue {
    return [[NKLibrary sharedLibrary] issueWithName:self.name];
}

-(void)addToNewsstand {
    if(!self.nkIssue) {
        [[NKLibrary sharedLibrary] addIssueWithName:self.name date:self.publication];
    }
}

-(void)writeToCache {
    // write the relevant issue metadata into cache directory
    NSURL *jsonURL = [NSURL URLWithString:@"issue.json" relativeToURL:[[self nkIssue] contentURL]];
    NSLog(@"%@",[jsonURL absoluteString]);
    NSOutputStream *os = [NSOutputStream outputStreamWithURL:jsonURL append:FALSE];
    [os open];
    NSError *error;
    if ([NSJSONSerialization writeJSONObject:dictionary toStream:os options:0 error:&error]<=0) {
        NSLog(@"Error writing JSON file");
    }
    [os close];
 
}

-(NSDate *)publication {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];
    NSDate *date = [dateFormatter dateFromString:[dictionary objectForKey:@"release"]];
    return date;
}

-(NSString *)name {
    return [NSString stringWithFormat:@"%@",[dictionary objectForKey:@"number"]];
}

-(NSString *)title {
    return [dictionary objectForKey:@"title"];
}

-(NSString *)editorsLetter {
    return [dictionary objectForKey:@"editors_letter_html"];
}

-(NSString *)editorsName {
    return [dictionary objectForKey:@"editors_name"];
}

// Q: will a property called "id" cause us woe? yes
-(NSNumber *)index {
    return [dictionary objectForKey:@"id"];
}

-(NSInteger)numberOfArticles {
    // might not be set yet...
    if(articles) {
        return [articles count];
    } else {
        return 0;
    }
}

-(NIAUArticle *)articleAtIndex:(NSInteger)index {
    return [articles objectAtIndex:index];
}

// TODO: how would we do getCover w/o completion block?
-(void)getCoverWithCompletionBlock:(void(^)(UIImage *img))block {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       UIImage *image = [self getCoverImage];
                       NSLog(@"got cover image %@",image);
                       // run the block on the main queue so it can 	do ui stuff
                       dispatch_async(dispatch_get_main_queue(), ^{
                           block(image);
                       });
                       
                   });
}

-(void)getEditorsImageWithCompletionBlock:(void(^)(UIImage *img))block {
    
    NSString *url = [[dictionary objectForKey:@"editors_photo"] objectForKey:@"url"];
    // online location of cover
    NSURL *photoURL = [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
    NSString *coverFileName = [photoURL lastPathComponent];
    // local URL to where the cover is/would be stored
    NSURL *photoCacheURL = [NSURL URLWithString:coverFileName relativeToURL:[self.nkIssue contentURL]];
    NSLog(@"trying to read cached editor's image from %@",photoCacheURL);
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:photoCacheURL]];
    
    if(image) {
        // cache hit
        block(image);
    } else {
        // cache miss, download
        NSLog(@"cache miss, downloading image from %@",photoURL);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                       ^{
                           // download image data
                           NSData *imageData = [NSData dataWithContentsOfCookielessURL:photoURL];
                           // what if imageData is nil? - seems to cope
                           UIImage *image = [UIImage imageWithData:imageData];
                           if(image) {
                               [imageData writeToURL:photoCacheURL atomically:YES];
                               block(image);
                           }
                       });
    }
}

-(void)requestArticles {
    NSLog(@"requestArticles called on %@",self);
    if(requestingArticles) {
        NSLog(@"already requesting articles");
    } else {
        requestingArticles = TRUE;
        // put dispatch magic here
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            
            // read from cache first and issue our first update
            
            articles = [NIAUArticle articlesFromIssue:self];		
            
            if ([articles count]>0) {
                NSLog(@"read #%d articles from cache",[articles count]);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticlesDidUpdateNotification object:self];
                });
//                NSLog(@"cache hit. stoppimg");
            } else {
                NSLog(@"no articles found in cache");
                [self downloadArticles];
            }
            requestingArticles = FALSE;
        });
    }
}

- (void)downloadArticles {
    NSURL *issueURL = [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@.json", [self index]] relativeToURL:[NSURL URLWithString:SITE_URL]];
    NSData *data = [NSData dataWithContentsOfCookielessURL:issueURL];
    if(data) {
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization
                              JSONObjectWithData:data
                              options:kNilOptions
                              error:&error];
        
        [[dict objectForKey:@"articles"] enumerateObjectsUsingBlock:^(id dict, NSUInteger idx, BOOL *stop) {
            
            // discard the returned objects and re-read cache after adding them (will preserve locally cached but remotely deleted data)
            [NIAUArticle articleWithIssue:self andDictionary:dict];
            
        }];
        articles = [NIAUArticle articlesFromIssue:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:ArticlesDidUpdateNotification object:self];
        });
        
    } else {
        
        // only send failure notification if there is nothing in the cache
        if ([articles count]<1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:ArticlesFailedUpdateNotification object:self];
            });
        }
        
    }

}

- (NSURL *)getWebURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@", self.index] relativeToURL:[NSURL URLWithString:SITE_URL]];
}

@end
