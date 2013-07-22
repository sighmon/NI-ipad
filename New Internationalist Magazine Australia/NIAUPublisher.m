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

#import "NIAUIssue.h"

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
           issues = [NIAUIssue issuesFromNKLibrary];
           
           ready = YES;
           
           // send notification
           dispatch_async(dispatch_get_main_queue(), ^{
               [[NSNotificationCenter defaultCenter] postNotificationName:PublisherDidUpdateNotification object:self];
           });
           
           
           NSURL *issuesURL = [NSURL URLWithString:@"issues.json" relativeToURL:[NSURL URLWithString:SITE_URL]];
           NSLog(@"try to download issues.json from %@", issuesURL);
           NSData *data = [NSData dataWithContentsOfURL:issuesURL];
           NSError *error;
           if(data) {
               NSArray *tmpIssues = [NSJSONSerialization
                            JSONObjectWithData:data //1
                            
                            options:kNilOptions
                            error:&error];
               [tmpIssues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                   
                   NIAUIssue *issue = [NIAUIssue issueWithDictionary:obj];
                   // maybe this too?
                   [issue addToNewsstand];
                   // TODO: this should be managed by the issue object itself
                   [issue writeToCache];
                   
                   
               }];
               
               // re-read issues
               issues = [NIAUIssue issuesFromNKLibrary];
               
               // TODO: make fancy diff of data for collection view
               // send second notification
               dispatch_async(dispatch_get_main_queue(), ^{
                   [[NSNotificationCenter defaultCenter] postNotificationName:PublisherDidUpdateNotification object:self];
               });
               
           } else {
               // TODO: what to do here?
               dispatch_async(dispatch_get_main_queue(), ^{
                   [[NSNotificationCenter defaultCenter] postNotificationName:PublisherFailedUpdateNotification object:self];
               });

            
           }
       
       });
}

-(NSInteger)numberOfIssues {
    if([self isReady] && issues) {
        return [issues count];
    } else {
        return 0;
    }
}

-(NIAUIssue *)issueAtIndex:(NSInteger)index {
    return [issues objectAtIndex:index];
}

@end
