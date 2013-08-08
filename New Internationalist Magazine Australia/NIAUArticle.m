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
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticleFailedUpdateNotification object:self];
                });
            }
            requestingBody = FALSE;
        });

    }
}


@end
