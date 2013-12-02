//
//  Publisher.m
//  Newsstand
//
//  Created by Carlo Vigiani on 18/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import "NIAUPublisher.h"
#import <NewsstandKit/NewsstandKit.h>
#import "NSData+Cookieless.h"
#import "local.h"

#import "NIAUIssue.h"

NSString *PublisherDidUpdateNotification = @"PublisherDidUpdate";
NSString *PublisherFailedUpdateNotification = @"PublisherFailedUpdate";

@interface NIAUPublisher ()

@end

@implementation NIAUPublisher


-(BOOL)isReady {
    return (issues != nil);
}

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
        issues = nil;
        requestingIssues = FALSE;
    }
    return self;
}

-(void)requestIssues {
    NSLog(@"getIssuesList");
    
    //guard against being called multiple times by impatient people
    if(!requestingIssues) {
        requestingIssues = TRUE;
    
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
           ^{
               issues = [NIAUIssue issuesFromNKLibrary];
               
               // send notification
               if ([issues count] > 0) {
                   dispatch_async(dispatch_get_main_queue(), ^{
                       [[NSNotificationCenter defaultCenter] postNotificationName:PublisherDidUpdateNotification object:self];
                   });
               }
               
               NSURL *issuesURL = [NSURL URLWithString:@"issues.json" relativeToURL:[NSURL URLWithString:SITE_URL]];
               NSLog(@"try to download issues.json from %@", issuesURL);
               NSData *data = [NSData dataWithContentsOfCookielessURL:issuesURL];
//               NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
               
               if(data) {
                   NSError *error;
                   NSArray *tmpIssues = [NSJSONSerialization
                                JSONObjectWithData:data //1
                                
                                options:kNilOptions
                                error:&error];
                   [tmpIssues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                       
                       // we could add each of these to our issues array
                       // but instead we re-read the nklibrary after building all of the issues
                       [NIAUIssue issueWithDictionary:obj];
                       
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
                   NSLog(@"download failed");
                   // only send failed notification if there is nothing in the cache
                   if ([issues count]<1) {
                       dispatch_async(dispatch_get_main_queue(), ^{
                           [[NSNotificationCenter defaultCenter] postNotificationName:PublisherFailedUpdateNotification object:self];
                       });
                   }

                
               }
               requestingIssues = FALSE;
           });
    }
}

-(void)forceDownloadIssues {
    // TODO: TOFIX seems to need to pause here for a bit else it crashes.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [self requestIssues];
    });
}

-(NSInteger)numberOfIssues {
    if(issues) {
        return [issues count];
    } else {
        return 0;
    }
}

-(NIAUIssue *)issueAtIndex:(NSInteger)index {
    return [issues objectAtIndex:index];
}

-(NIAUIssue *)issueWithName:(NSString *)name {
    // TODO: Catch out of bounds exception when the article doesn't get found.
    return [issues objectAtIndex:[issues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        //        NSLog(@"Object: %@, railsID: %@",[obj railsID], railsID);
        return ([[obj name] isEqualToString:name]);
    }]];
}

@end
