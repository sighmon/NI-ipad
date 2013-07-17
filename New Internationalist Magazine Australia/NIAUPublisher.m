//
//  Publisher.m
//  Newsstand
//
//  Created by Carlo Vigiani on 18/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import "NIAUPublisher.h"
#import <NewsstandKit/NewsstandKit.h>
#import "local.h"

NSString *PublisherDidUpdateNotification = @"PublisherDidUpdate";
NSString *PublisherFailedUpdateNotification = @"PublisherFailedUpdate";

@interface NIAUPublisher ()



@end

@implementation NIAUPublisher

@synthesize ready;

static NIAUPublisher *instance =nil;
+(NIAUPublisher *)getInstance
{
    @synchronized(self)
    {
        if(instance==nil)
        {
            
            instance= [NIAUPublisher new];
        }
    }
    return instance;
}

-(id)init {
    self = [super init];
    
    if(self) {
        ready = NO;
        issues = nil;
    }
    return self;
}

-(void)getIssuesList {
    NSLog(@"getIssuesList");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
                   ^{
                       bool cached = false;
                       NSURL *issuesURL = [NSURL URLWithString:@"issues.json" relativeToURL:[NSURL URLWithString:SITE_URL]];
                       NSLog(@"try to download issues.json from %@", issuesURL);
                       NSMutableArray *tmpIssues;
                       NSData *data = [NSData dataWithContentsOfURL:issuesURL];
                       if (!data) {
                           NSLog(@"download failed, building from NKLibrary");
                           NKLibrary *nkLibrary = [NKLibrary sharedLibrary];
                           tmpIssues = [NSMutableArray arrayWithCapacity:[[nkLibrary issues] count]];
                           [[nkLibrary issues] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                               NKIssue *issue = (NKIssue *)obj;
                               NSError *error;
                               // local json URL
                               NSURL *jsonURL = [NSURL URLWithString:@"issue.json" relativeToURL:[issue contentURL]];
                               NSData *data = [NSData dataWithContentsOfURL:jsonURL];
                               [tmpIssues addObject:[NSJSONSerialization JSONObjectWithData:data options:kNilOptions
                                                                                      error:&error]];
                           }];
                           
                           cached = true;
                       } else {
                           NSError *error;
                           tmpIssues = [NSJSONSerialization
                                        JSONObjectWithData:data //1
                                        
                                        options:kNilOptions
                                        error:&error];
                       }
                       
                       if(!tmpIssues) {
                           NSLog(@"null tmpIssues");
                           dispatch_async(dispatch_get_main_queue(), ^{
                               [[NSNotificationCenter defaultCenter] postNotificationName:PublisherFailedUpdateNotification object:self];
                           });
                       } else {
                           issues = [[NSArray alloc] initWithArray:tmpIssues];
                           ready = YES;
                           if (!cached)
                               [self addIssuesInNewsstand];
                           NSLog(@"%@",issues);
                           dispatch_async(dispatch_get_main_queue(), ^{
                               [[NSNotificationCenter defaultCenter] postNotificationName:PublisherDidUpdateNotification object:self];
                           });
                       }
                       
                    });
}

-(void)addIssuesInNewsstand {
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    //2013-07-01T00:00:00Z
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];

    [issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *name = [self nameOfIssue:(NSDictionary *)obj];
        NKIssue *nkIssue = [nkLib issueWithName:name];
        if(!nkIssue) {
            NSDate *date = [dateFormatter dateFromString:[(NSDictionary *)obj objectForKey:@"release"]];
            nkIssue = [nkLib addIssueWithName:name date:date];
            
            // write the relevant issue metadata into cache directory
            NSURL *jsonURL = [NSURL URLWithString:@"issue.json" relativeToURL:nkIssue.contentURL];
            NSLog(@"%@",[jsonURL absoluteString]);
            NSOutputStream *os = [NSOutputStream outputStreamWithURL:jsonURL append:FALSE];
            [os open];
            NSError *error;
            if ([NSJSONSerialization writeJSONObject:obj toStream:os options:0 error:&error]<=0) {
                NSLog(@"Error writing JSON file");
            }
            [os close];
        }
        NSLog(@"Issue: %@",nkIssue);
    }];
}

-(NSInteger)numberOfIssues {
    if([self isReady] && issues) {
        return [issues count];
    } else {
        return 0;
    }
}

-(NSDictionary *)issueAtIndex:(NSInteger)index {
    return [issues objectAtIndex:index];
}

-(NSString *)titleOfIssue:(NSDictionary *)issue {
    return [issue objectForKey:@"title"];
}

-(NSString *)titleOfIssueAtIndex:(NSInteger)index {
    return [self titleOfIssue:[self issueAtIndex:index]];
}

-(NSString *)nameOfIssue:(NSDictionary *)issue {
    return [NSString stringWithFormat:@"%@",[issue objectForKey:@"number"]];
}

-(NSString *)nameOfIssueAtIndex:(NSInteger)index {
    return [self nameOfIssue:[self issueAtIndex:index]];
}

-(void)setCoverOfIssueAtIndex:(NSInteger)index  completionBlock:(void(^)(UIImage *img))block {
    NSDictionary *issue = [self issueAtIndex:index];
    NKIssue *nkIssue = [[NKLibrary sharedLibrary] issueWithName:[self nameOfIssue:issue]];
    
    NSDictionary *dict = [[issue objectForKey:@"cover"] objectForKey:@"thumb2x"];
    // online location of cover
    NSURL *coverURL = [NSURL URLWithString:[dict objectForKey:@"url"] relativeToURL:[NSURL URLWithString:SITE_URL]];
    NSString *coverFileName = [coverURL lastPathComponent];
    // local URL to where the cover is/would be stored
    NSURL *coverCacheURL = [NSURL URLWithString:coverFileName relativeToURL:[nkIssue contentURL]];
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

-(UIImage *)coverImageForIssue:(NKIssue *)nkIssue {
    NSString *name = nkIssue.name;
    for(NSDictionary *issueInfo in issues) {
        if([name isEqualToString:[issueInfo objectForKey:@"Name"]]) {
            NSString *coverPath = [issueInfo objectForKey:@"Cover"];
            NSString *coverName = [coverPath lastPathComponent];
            NSString *coverFilePath = [CacheDirectory stringByAppendingPathComponent:coverName];
            UIImage *image = [UIImage imageWithContentsOfFile:coverFilePath];
            return image;
        }
    }
    return nil;
}

-(NSURL *)contentURLForIssueWithName:(NSString *)name {
    __block NSURL *contentURL=nil;
    [issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        // TODO: append issue number to keep this unique (or only use issue number maybe)
        NSString *aName = [(NSDictionary *)obj objectForKey:@"Name"];
        if([aName isEqualToString:name]) {
            contentURL = [NSURL URLWithString:[(NSDictionary *)obj objectForKey:@"Content"]];
            *stop=YES;
        }
    }];
    NSLog(@"Content URL for issue with name %@ is %@",name,contentURL);
    return contentURL;
}

-(NSString *)downloadPathForIssue:(NKIssue *)nkIssue {
    return [[nkIssue.contentURL path] stringByAppendingPathComponent:@"magazine.pdf"];
}

@end
