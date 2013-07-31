//
//  NIAUIssue.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 24/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUIssue.h"
#import "local.h"

NSString *ArticlesDidUpdateNotification = @"ArticlesDidUpdate";
NSString *ArticlesFailedUpdateNotification = @"ArticlesFailedUpdate";


@implementation NIAUIssue

BOOL requestingArticles;

-(id)init {
    if (self = [super init]) {
        requestingArticles = false;
    }
    return self;
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
    return [dictionary objectForKey:@"editors_letter"];
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
    
    NSString *url = [[[dictionary objectForKey:@"cover"] objectForKey:@"thumb2x"] objectForKey:@"url"];
    // online location of cover
    NSURL *coverURL = [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
    NSString *coverFileName = [coverURL lastPathComponent];
    // local URL to where the cover is/would be stored
    NSURL *coverCacheURL = [NSURL URLWithString:coverFileName relativeToURL:[self.nkIssue contentURL]];
    NSLog(@"trying to read cached image from %@",coverCacheURL);
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:coverCacheURL]];
    
    if(image) {
        // cache hit
        block(image);
    } else {
        // cache miss, download
        NSLog(@"cache miss, downloading image from %@",coverURL);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
           ^{
               // download image data
               NSData *imageData = [NSData dataWithContentsOfURL:coverURL];
               // what if imageData is nil? - seems to cope
               UIImage *image = [UIImage imageWithData:imageData];
               if(image) {
                   [imageData writeToURL:coverCacheURL atomically:YES];
                   block(image);
               }
           });
    }
}

-(void)requestArticles {
    if(!requestingArticles) {
        requestingArticles = TRUE;
        // put dispatch magic here
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            
            //TODO: read from cache first and issue our first update
            NSURL *issueURL = [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@.json", [self index]] relativeToURL:[NSURL URLWithString:SITE_URL]];
            NSData *data = [NSData dataWithContentsOfURL:issueURL];
            if(data) {
                NSError *error;
                NSDictionary *dict = [NSJSONSerialization
                                      JSONObjectWithData:data
                                      options:kNilOptions
                                      error:&error];
                NSMutableArray *tmpArticles = [NSMutableArray arrayWithCapacity:1];
                [[dict objectForKey:@"articles"] enumerateObjectsUsingBlock:^(id dict, NSUInteger idx, BOOL *stop) {
                    
                    // TODO: discard these objects and re-read cache after adding them (will preserve locally cached but remotely deleted data)
                    [tmpArticles addObject:[NIAUArticle articleWithIssue:self andDictionary:dict]];
                    
                }];
                articles = [NSArray arrayWithArray:tmpArticles];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticlesDidUpdateNotification object:self];
                });
                
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticlesFailedUpdateNotification object:self];
                });

                // failure notification
            }
            
            requestingArticles = FALSE;
        });
    }
}

@end
